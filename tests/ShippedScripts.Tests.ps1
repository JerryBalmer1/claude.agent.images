#Requires -Version 7.4

<#
    Every script under src/ has a caller.

    src/ ships in both images (COPY src/ /opt/leash/src/). A script there that nothing calls is
    shipped code nobody runs: it is carried into the leash, it drifts, and a defect in it is found
    only by accident. src/LedgerReceipt.ps1 was exactly that - two defects fixed in I11, still no
    caller - and was deleted in I12 PR 5 (forensic chain seq 40, DECISIONS.md).

    A caller is a reference by file name from build/, scripts/, hooks/, entrypoint.ps1 or another
    file under src/. tests/ does not count: a test proves a script works, not that anything uses it.
#>

BeforeDiscovery {
    $root = Split-Path -Parent $PSScriptRoot
    Push-Location $root
    try { $script:Shipped = @(git ls-files -- 'src/*.ps1' | ForEach-Object { @{ Rel = $_; Name = Split-Path -Leaf $_ } }) }
    finally { Pop-Location }
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:Root = Get-RepoRoot
    Push-Location $script:Root
    try { $script:Callers = @(git ls-files -- 'build/' 'scripts/' 'hooks/' 'entrypoint.ps1' 'src/') }
    finally { Pop-Location }
}

Describe 'Every shipped script has a caller' {
    It 'has shipped scripts to check (<Count> under src/)' -ForEach @(@{ Count = $script:Shipped.Count }) {
        $Count | Should -BeGreaterThan 0
    }

    It '<Rel> is called from build/, scripts/, hooks/, entrypoint.ps1 or src/' -ForEach $script:Shipped {
        $by = foreach ($c in $script:Callers) {
            if ($c -eq $Rel) { continue }
            $full = Join-Path $script:Root $c
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
            if ([System.IO.File]::ReadAllText($full).Contains($Name)) { $c }
        }
        @($by).Count | Should -BeGreaterThan 0 -Because "nothing outside tests/ references $Name, so the images ship it and nothing runs it"
    }
}
