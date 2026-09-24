#Requires -Version 7.4

<#
    tests/run.ps1 runs its suite from a clone whatever the clone's folder is called.

    Found by claude.agent.tools T0 (corpus/images-249752d.jsonl, directory-name-guard at
    tests/run.ps1:27): the runner threw NOT IN CLAUDE.AGENT.IMAGES unless the caller's git toplevel
    ended in claude.agent.images. That refused every clone under another name, and it refused the
    container, where the repository is mounted at /work. Forensic chain seq 26.

    The test clones the COMMITTED HEAD into a folder whose name is a fresh guid, drops one untracked
    probe test into it, and runs the clone's own runner from inside the clone, in a child pwsh. From
    inside, because the removed guard read the caller's current directory: a runner started from
    this repository's root would have passed it for the wrong reason.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
}

Describe 'tests/run.ps1 does not care what its folder is called' {
    BeforeAll {
        $script:Box = New-LeashSandbox
        $script:Clone = Join-Path $script:Box.Root ([guid]::NewGuid().ToString('n'))

        # Native errors are data here, not exceptions: a failed clone is asserted on below.
        $PSNativeCommandUseErrorActionPreference = $false
        $script:CloneOut = (& git clone -q --no-hardlinks $script:RepoRoot $script:Clone 2>&1 | Out-String)
        $script:CloneExit = $LASTEXITCODE

        $script:Probe = Join-Path $script:Clone 'tests' 'Probe.Folder.Tests.ps1'
        if (Test-Path -LiteralPath (Join-Path $script:Clone 'tests')) {
            [System.IO.File]::WriteAllText($script:Probe, "Describe 'probe' { It 'runs' { 1 | Should -Be 1 } }`n")
        }

        $script:Driver = Join-Path $script:Box.Root 'drive.ps1'
        [System.IO.File]::WriteAllText($script:Driver, (@(
                    '#Requires -Version 7.4'
                    "Set-Location -LiteralPath '$($script:Clone)'"
                    "& '$(Join-Path $script:Clone 'tests' 'run.ps1')' -Path '$($script:Probe)'"
                    'exit $LASTEXITCODE'
                ) -join "`n"))
    }

    AfterAll { Remove-Item -LiteralPath $script:Box.Root -Recurse -Force -ErrorAction SilentlyContinue }

    It 'clones into a folder that is not named claude.agent.images' {
        $script:CloneExit | Should -Be 0 -Because "git clone said: $($script:CloneOut)"
        (Split-Path -Leaf $script:Clone) | Should -Not -Match 'claude\.agent\.images'
    }

    It 'runs the probe through the clone''s own runner and does not refuse on the folder name' {
        $r = Invoke-LeashScript -Path $script:Driver
        $all = "$($r.StdOut)`n$($r.StdErr)"
        $all | Should -Not -Match 'NOT IN' -Because 'the runner refused on the folder name'
        $r.ExitCode | Should -Be 0 -Because "the runner said: $all"
        $r.StdOut | Should -Match 'SUITE: 1 passed, 0 failed, 0 skipped'
    }
}
