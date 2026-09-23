#Requires -Version 7.4

<#
    The entrypoint's job is to refuse. These tests assert that each refusal has
    its own exit code, because "the container failed to start" is not a
    diagnosis — the operator needs to know whether the mount is missing, the
    principal is unset, or the chain has been tampered with, and a single
    exit 1 for all three tells them nothing.

    The success cases matter just as much as the failures: a gate that refuses
    everything is as broken as one that refuses nothing, and an empty chain on
    a fresh mount has to be allowed or the leash could never be started once.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    $script:Entrypoint = Join-Path $script:RepoRoot 'entrypoint.ps1'
    $script:Sentinel = Join-Path $script:RepoRoot 'hooks' 'sentinel.ps1'
    $script:LedgerModule = Get-LedgerManifestPath
    $script:GoodSettings = Join-Path $script:RepoRoot 'managed-settings.json'

    function script:Invoke-Entrypoint {
        param(
            [string]$SettingsPath,
            [string]$LedgerDir,
            [AllowNull()][string]$Principal = 'run-01-test',
            [string[]]$Command = @(),
            [hashtable]$Extra = @{}
        )
        $vars = @{
            LEASH_SETTINGS_PATH = $SettingsPath
            LEASH_LEDGER_DIR    = $LedgerDir
            LEASH_LEDGER_MODULE = $script:LedgerModule
            LEDGER_PRINCIPAL    = $Principal
        }
        # Not named $env: that shadows the environment provider drive inside this scope.
        foreach ($k in $Extra.Keys) { $vars[$k] = $Extra[$k] }
        return Invoke-LeashScript -Path $script:Entrypoint -Arguments $Command -Stdin '' -Environment $vars
    }

    function script:New-Settings {
        # $MutateArg is passed to the scriptblock explicitly rather than left
        # to be picked up from the caller's scope. An unbound scriptblock
        # resolves its variables dynamically at invocation, so a name used
        # inside it can silently bind to a local of THIS function instead of
        # the caller's — which is exactly how `$o.$name` started assigning to a
        # property named after the output file.
        param(
            [string]$Root,
            [string]$FileName,
            [scriptblock]$Mutate,
            $MutateArg
        )
        $obj = Get-Content -LiteralPath $script:GoodSettings -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
        if ($Mutate) { & $Mutate $obj $MutateArg }
        $path = Join-Path $Root $FileName
        $obj | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding utf8
        return $path
    }
}

Describe 'Entrypoint: refusals have distinct exit codes' -Tag 'Ledger' {
    BeforeEach { $script:Box = New-LeashSandbox }
    AfterEach { Remove-LeashSandbox -Root $script:Box.Root }

    It 'exits 10 when the managed settings file is missing' {
        $r = Invoke-Entrypoint -SettingsPath (Join-Path $script:Box.Root 'absent.json') -LedgerDir $script:Box.LedgerDir
        $r.ExitCode | Should -Be 10
        $r.StdErr | Should -Match 'managed settings missing'
    }

    It 'exits 11 when the settings are not valid JSON' {
        $bad = Join-Path $script:Box.Root 'bad.json'
        Set-Content -LiteralPath $bad -Value '{ not json' -Encoding utf8
        $r = Invoke-Entrypoint -SettingsPath $bad -LedgerDir $script:Box.LedgerDir
        $r.ExitCode | Should -Be 11
    }

    It 'exits 11 when <Flag> is not true' -ForEach @(
        @{ Flag = 'allowManagedHooksOnly' }
        @{ Flag = 'disableBypassPermissionsMode' }
    ) {
        $path = New-Settings -Root $script:Box.Root -FileName "no-$Flag.json" `
            -Mutate { param($o, $f) $o.$f = $false } -MutateArg $Flag
        $r = Invoke-Entrypoint -SettingsPath $path -LedgerDir $script:Box.LedgerDir
        $r.ExitCode | Should -Be 11
        $r.StdErr | Should -Match $Flag
    }

    It 'exits 11 when no PreToolUse hook is registered' {
        $path = New-Settings -Root $script:Box.Root -FileName 'nohook.json' -Mutate {
            param($o) $o.hooks.PreToolUse = @()
        }
        $r = Invoke-Entrypoint -SettingsPath $path -LedgerDir $script:Box.LedgerDir
        $r.ExitCode | Should -Be 11
        $r.StdErr | Should -Match 'PreToolUse'
    }

    It 'exits 11 when a gated tool is in permissions.allow (claude-code#18312)' {
        $path = New-Settings -Root $script:Box.Root -FileName 'allow.json' -Mutate {
            param($o) $o.permissions.allow = @('Bash(git)')
        }
        $r = Invoke-Entrypoint -SettingsPath $path -LedgerDir $script:Box.LedgerDir
        $r.ExitCode | Should -Be 11
        $r.StdErr | Should -Match '18312'
    }

    It 'exits 12 when LEDGER_PRINCIPAL is unset' {
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir -Principal $null
        $r.ExitCode | Should -Be 12
        $r.StdErr | Should -Match 'LEDGER_PRINCIPAL unset'
    }

    It 'exits 13 when the ledger directory is not mounted' {
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir (Join-Path $script:Box.Root 'absent')
        $r.ExitCode | Should -Be 13
        $r.StdErr | Should -Match 'not mounted'
    }

    It 'exits 14 when the chain is broken' {
        foreach ($i in 1..3) {
            $null = Invoke-LeashScript -Path $script:Sentinel -Stdin '{"tool_name":"Read"}' -Environment @{
                LEASH_LEDGER_PATH   = $script:Box.LedgerPath
                LEASH_LEDGER_MODULE = $script:LedgerModule
                LEDGER_PRINCIPAL    = 'run-01-test'
            }
        }
        @(Get-Content -LiteralPath $script:Box.LedgerPath).Count | Should -Be 3

        $lines = Get-Content -LiteralPath $script:Box.LedgerPath
        $lines[1] = $lines[1].Replace('"prev":"', '"prev":"0')
        Set-Content -LiteralPath $script:Box.LedgerPath -Value $lines -Encoding utf8

        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir
        $r.ExitCode | Should -Be 14
        $r.StdErr | Should -Match 'chain is broken'
    }

    It 'exits 15 when the requested command is not on PATH' {
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir `
            -Command @('definitely-not-a-real-command-xyzzy')
        $r.ExitCode | Should -Be 15
        $r.StdErr | Should -Match 'command not found'
    }

    It 'gives every refusal its own exit code' {
        # The point of the whole Describe, asserted directly rather than left
        # as something a reader has to notice by scanning the cases above.
        $codes = @(
            (Invoke-Entrypoint -SettingsPath (Join-Path $script:Box.Root 'absent.json') -LedgerDir $script:Box.LedgerDir).ExitCode
            (Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir -Principal $null).ExitCode
            (Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir (Join-Path $script:Box.Root 'absent')).ExitCode
        )
        $codes | Should -Be @(10, 12, 13)
        ($codes | Select-Object -Unique).Count | Should -Be 3
    }
}

Describe 'Entrypoint: what it must NOT refuse' -Tag 'Ledger' {
    BeforeEach { $script:Box = New-LeashSandbox }
    AfterEach { Remove-LeashSandbox -Root $script:Box.Root }

    It 'accepts a fresh mount with no receipts yet' {
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir
        $r.ExitCode | Should -Be 0 -Because 'an empty chain is a valid chain, or the leash could never start once'
        $r.StdErr | Should -Match 'genesis'
    }

    It 'accepts an intact chain and reports the head hash' {
        foreach ($i in 1..2) {
            $null = Invoke-LeashScript -Path $script:Sentinel -Stdin '{"tool_name":"Read"}' -Environment @{
                LEASH_LEDGER_PATH   = $script:Box.LedgerPath
                LEASH_LEDGER_MODULE = $script:LedgerModule
                LEDGER_PRINCIPAL    = 'run-01-test'
            }
        }
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir
        $r.ExitCode | Should -Be 0
        $r.StdErr | Should -Match 'chain intact: 2 receipt\(s\), head=[0-9a-f]{64}'
    }

    It 'never writes to the settings file it validates' {
        $before = (Get-FileHash -LiteralPath $script:GoodSettings -Algorithm SHA256).Hash
        $null = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir
        (Get-FileHash -LiteralPath $script:GoodSettings -Algorithm SHA256).Hash |
            Should -BeExactly $before -Because 'an entrypoint that repairs its own policy is not a gate'
    }

    It 'leaves no write-probe behind in the ledger directory' {
        $null = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir
        @(Get-ChildItem -LiteralPath $script:Box.LedgerDir -Force -Filter '.leash-write-probe-*').Count |
            Should -Be 0
    }

    It 'passes a command through with its own flags intact' {
        # The param() block bug: `pwsh -NoProfile -c ...` used to be bound to
        # the entrypoint's own parameters and die before anything ran.
        $pwshPath = Get-PwshPath
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir `
            -Command @($pwshPath, '-NoProfile', '-Command', '"passed-through"')
        $r.ExitCode | Should -Be 0
        $r.StdOut | Should -Match 'passed-through'
    }
}

Describe 'Entrypoint: the claude binary, carried over from entrypoint.sh' -Tag 'Ledger' {
    <#
        entrypoint.sh ran `claude --version` unconditionally and refused to start if claude was
        absent, whatever command it had been handed. entrypoint.ps1 replaced it and kept only a
        check that the command it was ASKED to exec resolves (exit 15) - so a leash image built
        without claude in it started happily as long as you asked it for something else. That is
        FINDING-M8, and this is the port. The .sh is not resurrected.

        Why it is opt-in rather than unconditional: these tests run entrypoint.ps1 on the HOST,
        where claude is not installed and is not supposed to be. An unconditional refusal would
        make every test above fail for a reason that has nothing to do with what they assert.
        LEASH_REQUIRE_CLAUDE is set by the Dockerfiles - the image is the thing that can promise
        claude is present, so the image is the thing that demands it. tests/Image.Tests.ps1
        asserts both Dockerfiles set it, which is what stops this being opt-in in practice.
    #>
    BeforeEach { $script:Box = New-LeashSandbox }
    AfterEach { Remove-LeashSandbox -Root $script:Box.Root }

    It 'exits 16 when claude is required but absent' {
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir -Extra @{
            LEASH_REQUIRE_CLAUDE = '1'
            LEASH_CLAUDE_BIN     = 'claude-that-is-definitely-not-installed'
        }
        $r.ExitCode | Should -Be 16
        $r.StdErr | Should -Match 'claude'
    }

    It 'does not refuse when claude is not required' {
        # The host case, and the guard against this port breaking every other test here.
        #
        # LEASH_REQUIRE_CLAUDE is cleared EXPLICITLY rather than just left unset. In the
        # container this suite runs inside the leash image, which sets LEASH_REQUIRE_CLAUDE=1
        # as an ENV - so "unset" on the host is "1" in here, and this test failed in-container
        # while passing on the host. Found by the in-container run, which is what it is for.
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir -Extra @{
            LEASH_CLAUDE_BIN     = 'claude-that-is-definitely-not-installed'
            LEASH_REQUIRE_CLAUDE = $null   # $null REMOVES it; '' would merely blank it
        }
        $r.ExitCode | Should -Be 0
    }

    It 'records the version at boot when the binary is present' {
        # pwsh stands in for claude: it exists on every runner and answers --version. What is
        # being asserted is that the entrypoint SHELLS OUT and puts the answer on stderr, which
        # is the half of entrypoint.sh's behaviour that carried no exit code with it. F-22 wants
        # the gated tool set derived from the pinned version, and this line is where that
        # version is witnessed at runtime.
        $r = Invoke-Entrypoint -SettingsPath $script:GoodSettings -LedgerDir $script:Box.LedgerDir -Extra @{
            LEASH_REQUIRE_CLAUDE = '1'
            LEASH_CLAUDE_BIN     = (Get-PwshPath)
        }
        $r.ExitCode | Should -Be 0
        $r.StdErr | Should -Match 'PowerShell \d+\.\d+'
    }
}
