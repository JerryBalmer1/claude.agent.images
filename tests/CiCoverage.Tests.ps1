#Requires -Version 7.4

<#
    Nothing is silent in the `pester` required check, and the in-container wall time is visible.

    Until I12 PR 4, scripts/ci/Invoke-Tests.ps1 excluded the Docker tag: the 21 Docker-tagged tests
    were reported NotRun and the gate tolerated them because the filter explained them. They ran
    only on a host with docker, and in CI nowhere. Ubuntu runners ship docker, so the check now
    runs them, and a hard gate fails the check on any NotRun at all. Forensic chain seq 36.

    Measured on the scripts themselves, so this runs everywhere, the images included.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:Root = Get-RepoRoot
    $script:InvokeTests = Join-Path $script:Root 'scripts' 'ci' 'Invoke-Tests.ps1'
}

Describe 'The pester check runs every test' {
    It 'Invoke-Tests.ps1 excludes no tag' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:InvokeTests, [ref]$null, [ref]$null)
        $assignments = @($ast.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $n.Left.Extent.Text -eq '$excludeTag'
                }, $true))
        $assignments.Count | Should -Be 1 -Because 'one place decides what the check skips'
        $assignments[0].Right.Extent.Text | Should -Be '@()' -Because 'an excluded tag is a set of tests CI never runs'
    }

    It 'Invoke-Tests.ps1 fails the check on any NotRun' {
        (Get-Content -LiteralPath $script:InvokeTests -Raw) | Should -Match '\$result\.NotRunCount\s+-gt\s+0'
    }
}

Describe 'The in-container wall time is reported' {
    It 'Test.InContainer prints it' {
        (Get-Content -LiteralPath (Join-Path $script:Root 'build' 'tasks' 'Test.build.ps1') -Raw) | Should -Match 'wall=\{\d\}s'
    }

    It 'the incontainer CI job prints it' {
        (Get-Content -LiteralPath (Join-Path $script:Root 'scripts' 'ci' 'Invoke-InContainer.ps1') -Raw) | Should -Match 'wall=\{\d\}s'
    }
}
