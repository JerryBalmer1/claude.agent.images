#Requires -Version 7.4

<#
    Two kinds of assertion live here.

    The static ones read the Dockerfiles and need nothing installed. They catch
    pin drift between the two images, which is the failure that would otherwise
    only show up as "the developer image behaves differently and nobody knows
    why".

    The rest are tagged Docker: they build the images and inspect the result.
    Test.InContainer excludes that tag, because the container has no docker
    daemon — those assertions are about the image, so they run on the host that
    can build it.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    $script:LeashDockerfile = Join-Path $script:RepoRoot 'Dockerfile'
    $script:DevDockerfile = Join-Path $script:RepoRoot 'images' 'developer' 'Dockerfile'
    $script:LeashTag = 'claude.pwsh.image.leash:run-01'
    $script:DevTag = 'claude.pwsh.image.developer:run-01'

    function script:Get-DockerfileArg {
        param([string]$Path, [string]$Name)
        $line = Get-Content -LiteralPath $Path | Where-Object { $_ -match "^ARG\s+$Name=" } | Select-Object -First 1
        if (-not $line) { return $null }
        return ($line -replace "^ARG\s+$Name=", '').Trim()
    }

    function script:Invoke-Docker {
        param([string[]]$Arguments, [int]$TimeoutSeconds = 900)
        return Invoke-Native -FilePath 'docker' -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds
    }
}

Describe 'Dockerfile pins (static)' {
    It 'pins the base image by digest, not by tag' {
        $base = Get-DockerfileArg -Path $script:LeashDockerfile -Name 'BASE_IMAGE'
        $base | Should -Match '^ubuntu:24\.04@sha256:[0-9a-f]{64}$'
    }

    It 'does not use the deprecated PowerShell MCR images' {
        # assessment 2026-09-21: that base was rejected, last published 2025-02.
        #
        # Comment lines are stripped first. Both Dockerfiles explain in prose
        # why that base is NOT used, and a test that cannot tell an instruction
        # from an explanation of why the instruction is absent would force the
        # reason to be deleted to stay green.
        foreach ($f in @($script:LeashDockerfile, $script:DevDockerfile)) {
            $instructions = (Get-Content -LiteralPath $f |
                Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
            $instructions | Should -Not -Match 'mcr\.microsoft\.com/powershell'
        }
    }

    It 'pins <_> identically in both images' -ForEach @('BASE_IMAGE', 'PWSH_URL', 'PWSH_SHA256') {
        $leash = Get-DockerfileArg -Path $script:LeashDockerfile -Name $_
        $dev = Get-DockerfileArg -Path $script:DevDockerfile -Name $_
        $leash | Should -Not -BeNullOrEmpty
        $dev | Should -BeExactly $leash -Because 'the developer image must share the leash image base'
    }

    It 'makes the runtime claude check mandatory in both images' -ForEach @(
        @{ File = 'Dockerfile' }
        @{ File = 'images/developer/Dockerfile' }
    ) {
        # entrypoint.ps1's claude check is opt-in via LEASH_REQUIRE_CLAUDE, because the
        # entrypoint's own suite runs it on a host where claude is not installed and is not
        # supposed to be. THIS is what stops "opt-in" from meaning "off in practice": the image
        # is the thing that can promise claude is present, so the image is the thing that
        # demands it. Without this assertion the port in FINDING-M8 is decorative.
        $instructions = (Get-Content -LiteralPath (Join-Path $script:RepoRoot $File) |
            Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $instructions | Should -Match '(?m)^ENV\s+LEASH_REQUIRE_CLAUDE=1\s*$'
    }

    It 'pins a 7.6.x PowerShell tarball with a sha256' {
        (Get-DockerfileArg -Path $script:LeashDockerfile -Name 'PWSH_URL') | Should -Match 'v7\.6\.\d+/powershell-7\.6\.\d+-linux-x64\.tar\.gz$'
        (Get-DockerfileArg -Path $script:LeashDockerfile -Name 'PWSH_SHA256') | Should -Match '^[0-9a-f]{64}$'
    }

    It 'declares the 7.6 runtime FLOOR in exactly one place' {
        # BLOCKER-6. There were two independent [version]$MinimumPSVersion = '7.6' defaults, in
        # InContainer.Bootstrap.ps1 and InContainer.Test.ps1. A floor that exists in two places
        # is not a floor, it is a coincidence: the two can disagree and nothing notices.
        # InContainer.Test.ps1 now reads the Bootstrap parameter's default out of the AST.
        #
        # This counts MinimumPSVersion FLOOR LITERALS, not occurrences of the string "7.6".
        # A bare grep for 7.6 hits 56 places outside vendor/ - the two Dockerfile ARG pins, the
        # plan documents that discuss this very blocker, and this assertion itself. The pattern
        # is the one docs/plans/2026-09-21-oneshot/verify.ps1 already uses for "a floor", reused
        # rather than reinvented so the two cannot disagree about what they are counting.
        $floors = @(Select-String -Path (Join-Path $script:RepoRoot 'build' '*.ps1') `
                                  -Pattern 'MinimumPSVersion\s*=\s*.7\.6.')
        $floors.Count | Should -Be 1 -Because "the floor is declared once; found in $(($floors | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }) -join ', ')"
        $floors[0].Filename | Should -Be 'InContainer.Bootstrap.ps1'
    }

    It 'still resolves that floor to 7.6 from the other script' {
        # Guards the guard. Deleting the second literal would satisfy the count above even if
        # InContainer.Test.ps1 had been left with no floor at all, or with one that no longer
        # resolves. This asserts the reading end still works.
        $bootstrap = Join-Path $script:RepoRoot 'build' 'InContainer.Bootstrap.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($bootstrap, [ref]$null, [ref]$null)
        $p = $ast.ParamBlock.Parameters |
             Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPSVersion' } |
             Select-Object -First 1
        $p | Should -Not -BeNullOrEmpty
        ([version]$p.DefaultValue.Value) | Should -Be ([version]'7.6')
    }

    It 'leaves the Dockerfile ARG pins alone - a pin is not a floor' {
        # The distinction BLOCKER-6 turns on. Collapsing these into the floor was explicitly out
        # of scope: a Docker build-arg cannot read a PowerShell default, and the config file
        # that would unify them is the next pass.
        foreach ($f in @($script:LeashDockerfile, $script:DevDockerfile)) {
            (Get-DockerfileArg -Path $f -Name 'PWSH_URL') | Should -Match '7\.6\.\d+'
        }
    }

    It 'verifies the tarball BEFORE extracting it' -ForEach @(
        @{ File = 'Dockerfile' }
        @{ File = 'images/developer/Dockerfile' }
    ) {
        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $File) -Raw
        $verifyAt = $text.IndexOf('sha256sum -c')
        $extractAt = $text.IndexOf('tar -xzf')
        $verifyAt | Should -BeGreaterThan 0
        $extractAt | Should -BeGreaterThan 0
        $verifyAt | Should -BeLessThan $extractAt -Because 'verifying after extracting proves nothing'
    }

    It 'copies the vendored Ledger into <File>' -ForEach @(
        @{ File = 'Dockerfile' }
        @{ File = 'images/developer/Dockerfile' }
    ) {
        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $File) -Raw
        # Option A. core ships modules/ledger/ledger.psd1 LOWERCASE; the in-container
        # contract -- entrypoint.ps1, hooks/sentinel.ps1, build/InContainer.Test.ps1 -- asks for
        # /opt/leash/ledger/Ledger.psd1. On Linux that is a hard break, and it was measured, not
        # argued: with a plain directory COPY, Test-Path /opt/leash/ledger/Ledger.psd1 returned
        # False and Import-Module failed. So the manifest is RENAMED in the COPY and no runtime
        # file is edited. Asserting all three lines is asserting the repair.
        $text | Should -Match 'COPY vendor/claude\.agent\.core/modules/ledger/ledger\.psd1 /opt/leash/ledger/Ledger\.psd1'
        $text | Should -Match 'COPY vendor/claude\.agent\.core/modules/ledger/ledger\.psm1 /opt/leash/ledger/ledger\.psm1'
        $text | Should -Match 'COPY vendor/claude\.agent\.core/modules/ledger/python/ /opt/leash/ledger/python/'
    }

    It 'uses the PowerShell entrypoint, not the deleted shell one' -ForEach @(
        @{ File = 'Dockerfile' }
        @{ File = 'images/developer/Dockerfile' }
    ) {
        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $File) -Raw
        $text | Should -Match 'ENTRYPOINT \["pwsh"'
        $text | Should -Not -Match 'entrypoint\.sh'
    }

    It 'has no entrypoint.sh left in the repo' {
        (Join-Path $script:RepoRoot 'entrypoint.sh') | Should -Not -Exist
    }

    It 'keeps exactly one sentinel script' {
        @(Get-ChildItem -LiteralPath $script:RepoRoot -Recurse -Filter 'sentinel.ps1' -File |
            Where-Object { $_.FullName -notmatch '[\\/](vendor|\.git)[\\/]' }).Count |
            Should -Be 1 -Because 'two copies drift; one copy with a -Mode switch does not'
    }
}

Describe 'Image builds and runs correctly' -Tag 'Docker' {
    BeforeAll {
        # Absolute -f. A relative 'Dockerfile' resolves against the docker
        # process's working directory, which is not necessarily where Pester
        # was started from, and the failure reads as "no such file or
        # directory" rather than "your path was relative".
        $script:BuildLeash = Invoke-Docker -Arguments @('build', '-f', $script:LeashDockerfile, '-t', $script:LeashTag, $script:RepoRoot)
        $script:BuildDev = Invoke-Docker -Arguments @('build', '-f', (Join-Path $script:RepoRoot 'images' 'developer' 'Dockerfile'), '-t', $script:DevTag, $script:RepoRoot)
    }

    It 'builds the leash image' {
        $script:BuildLeash.ExitCode | Should -Be 0 -Because $script:BuildLeash.StdErr
    }

    It 'builds the developer image' {
        $script:BuildDev.ExitCode | Should -Be 0 -Because $script:BuildDev.StdErr
    }

    It '<Tag> runs as a non-root user' -ForEach @(
        @{ Tag = 'claude.pwsh.image.leash:run-01' }
        @{ Tag = 'claude.pwsh.image.developer:run-01' }
    ) {
        $r = Invoke-Docker -Arguments @('run', '--rm', '--entrypoint', 'sh', $Tag, '-c', 'id -u')
        $r.ExitCode | Should -Be 0
        $uid = [int]$r.StdOut.Trim()
        $uid | Should -Not -Be 0 -Because 'an agent running as root has no leash at all'
    }

    It '<Tag> ships PowerShell 7.6 or newer' -ForEach @(
        @{ Tag = 'claude.pwsh.image.leash:run-01' }
        @{ Tag = 'claude.pwsh.image.developer:run-01' }
    ) {
        $r = Invoke-Docker -Arguments @('run', '--rm', '--entrypoint', 'pwsh', $Tag, '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
        $r.ExitCode | Should -Be 0
        ([version]$r.StdOut.Trim()) | Should -BeGreaterOrEqual ([version]'7.6')
    }

    It '<Tag> has the pinned Pester available to the non-root user' -ForEach @(
        @{ Tag = 'claude.pwsh.image.leash:run-01' }
        @{ Tag = 'claude.pwsh.image.developer:run-01' }
    ) {
        $r = Invoke-Docker -Arguments @('run', '--rm', '--entrypoint', 'pwsh', $Tag, '-NoProfile', '-File', '/opt/leash/build/InContainer.Bootstrap.ps1')
        $r.ExitCode | Should -Be 0 -Because $r.StdErr
    }

    It '<Tag> keeps <Path> root-owned and 0555' -ForEach @(
        @{ Tag = 'claude.pwsh.image.leash:run-01'; Path = '/opt/leash/hooks' }
        @{ Tag = 'claude.pwsh.image.leash:run-01'; Path = '/opt/leash/hooks/sentinel.ps1' }
        @{ Tag = 'claude.pwsh.image.leash:run-01'; Path = '/opt/leash/entrypoint.ps1' }
        @{ Tag = 'claude.pwsh.image.leash:run-01'; Path = '/opt/leash/ledger/Ledger.psd1' }
        @{ Tag = 'claude.pwsh.image.leash:run-01'; Path = '/etc/claude-code/managed-settings.json' }
        @{ Tag = 'claude.pwsh.image.leash:run-01'; Path = '/etc/claude-code' }
        @{ Tag = 'claude.pwsh.image.developer:run-01'; Path = '/opt/leash/hooks/sentinel.ps1' }
        @{ Tag = 'claude.pwsh.image.developer:run-01'; Path = '/opt/leash/ledger/Ledger.psd1' }
        @{ Tag = 'claude.pwsh.image.developer:run-01'; Path = '/etc/claude-code/managed-settings.json' }
    ) {
        $r = Invoke-Docker -Arguments @('run', '--rm', '--entrypoint', 'stat', $Tag, '-c', '%a %U:%G', $Path)
        $r.ExitCode | Should -Be 0 -Because "$Path must exist in $Tag"
        $r.StdOut.Trim() | Should -BeExactly '555 root:root'
    }

    It 'the agent user cannot overwrite the sentinel it is gated by' {
        $r = Invoke-Docker -Arguments @('run', '--rm', '--entrypoint', 'sh', $script:LeashTag,
            '-c', 'echo tampered > /opt/leash/hooks/sentinel.ps1 2>/dev/null && echo WROTE || echo REFUSED')
        $r.StdOut.Trim() | Should -BeExactly 'REFUSED'
    }

    It 'the leash image denies Bash and writes a receipt on a mounted chain' {
        $box = New-LeashSandbox
        try {
            $r = Invoke-Docker -Arguments @('run', '--rm',
                '-e', 'LEDGER_PRINCIPAL=image-test',
                '-e', 'PAYLOAD={"tool_name":"Bash","tool_input":{"command":"id"}}',
                '-v', "$($box.LedgerDir):/ledger",
                '--entrypoint', 'pwsh', $script:LeashTag,
                '-NoProfile', '-Command', '$env:PAYLOAD | pwsh -NoProfile -File /opt/leash/hooks/sentinel.ps1')
            $r.ExitCode | Should -Be 0
            $body = ConvertFrom-JsonSafe -Text $r.StdOut.Trim()
            $body.hookSpecificOutput.permissionDecision | Should -BeExactly 'deny'
            $box.LedgerPath | Should -Exist
        }
        finally { Remove-LeashSandbox -Root $box.Root }
    }

    It 'the entrypoint refuses to start without a mounted ledger (exit 13)' {
        $r = Invoke-Docker -Arguments @('run', '--rm', '-e', 'LEDGER_PRINCIPAL=image-test',
            $script:LeashTag, 'pwsh', '-NoProfile', '-Command', 'exit 0')
        $r.ExitCode | Should -Be 13
        $r.StdErr | Should -Match 'not mounted'
    }

    It 'the entrypoint runs a command with its own flags once armed' {
        $box = New-LeashSandbox
        try {
            $r = Invoke-Docker -Arguments @('run', '--rm', '-e', 'LEDGER_PRINCIPAL=image-test',
                '-v', "$($box.LedgerDir):/ledger", $script:LeashTag,
                'pwsh', '-NoProfile', '-Command', '"armed-and-running"')
            $r.ExitCode | Should -Be 0 -Because $r.StdErr
            $r.StdOut | Should -Match 'armed-and-running'
        }
        finally { Remove-LeashSandbox -Root $box.Root }
    }
}
