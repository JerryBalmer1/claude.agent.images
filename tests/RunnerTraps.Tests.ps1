#Requires -Version 7.4

<#
    Two traps in the test gates, both met by claude in I12 and recorded in PR #21's body.

    1. A test file that fails to LOAD - a parse error, or a throw while Pester discovers it - is a
       failed container, not a failed test. Pester reports it in FailedContainersCount and leaves
       FailedCount at 0, and every gate here read only FailedCount: tests/run.ps1,
       Assert-SuiteClean (Test.Unit and CI's `pester`) and build/InContainer.Test.ps1. Measured at
       1f0c6d2: a file with a syntax error printed "Container failed: 1" and run.ps1 exited 0. The
       file's tests were in no count at all, so nothing said they had not run.

    2. tests/run.ps1 bound a second positional argument to -Evidence, and -Evidence starts a
       transcript with -Force. `run.ps1 a.Tests.ps1 b.Tests.ps1` overwrote b.Tests.ps1. Measured at
       1f0c6d2 on a scratch file: exit 0, and the file began "PowerShell transcript start".

    Each case runs the COMMITTED runner in a child pwsh against throwaway files in a sandbox.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    $script:Runner = Join-Path $script:RepoRoot 'tests' 'run.ps1'
}

Describe 'tests/run.ps1 fails when a test file fails to load' {
    BeforeAll {
        $script:Box = New-LeashSandbox
        $script:Broken = Join-Path $script:Box.Root 'Broken.Tests.ps1'
        # The closing braces are missing: this file does not parse.
        [System.IO.File]::WriteAllText($script:Broken, "Describe 'broken' {`n    It 'never runs' { 1 | Should -Be 1 `n")
        # A folder holding a passing file beside the broken one. A folder, because a second path
        # after -Path is exactly the stray positional argument the next Describe refuses.
        $script:Mixed = Join-Path $script:Box.Root 'mixed'
        $null = New-Item -ItemType Directory -Path $script:Mixed
        [System.IO.File]::WriteAllText((Join-Path $script:Mixed 'Good.Tests.ps1'), "Describe 'good' { It 'runs' { 1 | Should -Be 1 } }`n")
        Copy-Item -LiteralPath $script:Broken -Destination $script:Mixed
    }

    AfterAll { Remove-Item -LiteralPath $script:Box.Root -Recurse -Force -ErrorAction SilentlyContinue }

    It 'exits non-zero on a file that does not parse' {
        $r = Invoke-LeashScript -Path $script:Runner -Arguments @('-Path', $script:Broken)
        $r.ExitCode | Should -Not -Be 0 -Because "the runner said: $($r.StdOut)"
    }

    It 'names the file and the error, and counts it as not run' {
        $r = Invoke-LeashScript -Path $script:Runner -Arguments @('-Path', $script:Broken)
        $all = "$($r.StdOut)`n$($r.StdErr)"
        $all | Should -Match 'NOT LOADED: .*Broken\.Tests\.ps1'
        $all | Should -Match 'Missing closing'
        $r.StdOut | Should -Match 'SUITE: 0 passed, 0 failed, 0 skipped, not run: 1 file\(s\) failed to load'
    }

    It 'stays red when a passing file runs beside it' {
        $r = Invoke-LeashScript -Path $script:Runner -Arguments @('-Path', $script:Mixed)
        $r.StdOut | Should -Match 'SUITE: 1 passed, 0 failed, 0 skipped, not run: 1 file\(s\) failed to load'
        $r.ExitCode | Should -Not -Be 0
    }
}

Describe 'tests/run.ps1 refuses a stray positional argument' {
    BeforeAll {
        $script:Box = New-LeashSandbox
        $script:Good = Join-Path $script:Box.Root 'Good.Tests.ps1'
        $script:Victim = Join-Path $script:Box.Root 'Victim.Tests.ps1'
        [System.IO.File]::WriteAllText($script:Good, "Describe 'good' { It 'runs' { 1 | Should -Be 1 } }`n")
        $script:VictimText = "Describe 'victim' { It 'is not a transcript' { 1 | Should -Be 1 } }`n"
    }

    BeforeEach {
        [System.IO.File]::WriteAllText($script:Victim, $script:VictimText)
        $script:Before = @(Get-ChildItem -LiteralPath $script:Box.Root -Recurse -Force | ForEach-Object FullName)
    }

    AfterAll { Remove-Item -LiteralPath $script:Box.Root -Recurse -Force -ErrorAction SilentlyContinue }

    It 'exits non-zero on <Label> and writes nothing' -ForEach @(
        @{ Label = 'two positional paths'; Named = $false }
        @{ Label = '-Path then a positional path'; Named = $true }
    ) {
        $argv = if ($Named) { @('-Path', $script:Good, $script:Victim) } else { @($script:Good, $script:Victim) }
        # Both forms bound the second path to -Evidence before this fix.
        $r = Invoke-LeashScript -Path $script:Runner -Arguments $argv

        $r.ExitCode | Should -Not -Be 0 -Because "the runner said: $($r.StdOut) $($r.StdErr)"
        [System.IO.File]::ReadAllText($script:Victim) | Should -BeExactly $script:VictimText
        @(Get-ChildItem -LiteralPath $script:Box.Root -Recurse -Force | ForEach-Object FullName) |
            Should -Be $script:Before
    }

    It 'still writes the transcript when -Evidence is named' {
        $evidence = Join-Path $script:Box.Root 'evidence.txt'
        $r = Invoke-LeashScript -Path $script:Runner -Arguments @('-Path', $script:Good, '-Evidence', $evidence)
        $r.ExitCode | Should -Be 0 -Because "the runner said: $($r.StdOut)"
        Get-Content -LiteralPath $evidence -Raw | Should -Match 'SUITE: 1 passed, 0 failed, 0 skipped'
        Remove-Item -LiteralPath $evidence -Force
    }
}

Describe 'Assert-SuiteClean fails on a file that failed to load' {
    BeforeAll {
        Import-Module (Join-Path $script:RepoRoot 'build' 'Build.Helpers.psm1') -Force
    }

    It 'throws and names the file, with every test that did load passing' {
        # The shape Pester 6 returns for one passing test and one container that failed discovery.
        $result = [pscustomobject]@{
            PassedCount           = 1
            FailedCount           = 0
            FailedContainersCount = 1
            FailedContainers      = @([pscustomobject]@{
                    Item        = '/work/tests/Broken.Tests.ps1'
                    ErrorRecord = @([System.Management.Automation.ErrorRecord]::new(
                            [System.Exception]::new('Missing closing ''}'''), 'ParseError', 'ParserError', $null))
                })
            Tests                 = @([pscustomobject]@{ Result = 'Passed'; ExpandedPath = 'good.runs'; Tag = @(); Block = $null })
        }
        { Assert-SuiteClean -Result $result -Where 'probe' } |
            Should -Throw -ExpectedMessage '*1 test file(s) failed to load*Broken.Tests.ps1*Missing closing*'
    }
}
