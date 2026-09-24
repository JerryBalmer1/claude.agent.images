#Requires -Version 7.4

<#
    The ledger module is claude.agent.core's, and nothing that ships may still point at
    claude.build.ledger.

    Found by claude.agent.tools T0 (corpus/images-249752d.jsonl): src/LedgerReceipt.ps1:103 named
    /opt/leash/vendor/claude.build.ledger/..., a path no image has ever created, and :104 built the
    same dead host path out of Join-Path pieces. The inspector's dead-vendor-path rule caught :103
    and missed :104, because Join-Path splits the path - so the sweep below matches the NAME in
    any form, not the slash-joined literal. Forensic chain seq 24.

    The behavioural test that drove src/LedgerReceipt.ps1's Invoke-LedgerBootVerify was removed
    with that file in I12 PR 5 (forensic chain seq 40): nothing called it. The sweep stays - it
    guards every shipped file, not that one.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
}

# Titles say 'the retired ledger repository' rather than its name: the I11 postcondition is that no
# log line of the in-container run carries the old path, and Pester prints every title.
Describe 'No shipped file points at the retired ledger repository' {
    # The five places the packet names. images/developer/Dockerfile is the developer image's
    # Dockerfile and copies the same module, so it is swept too.
    It 'finds the retired ledger repository''s name in no tracked file under src/, hooks/, scripts/, entrypoint.ps1 or a Dockerfile' {
        Push-Location $script:RepoRoot
        try {
            $files = @(git ls-files -- 'src/' 'hooks/' 'scripts/' 'entrypoint.ps1' 'Dockerfile' 'images/developer/Dockerfile')
        }
        finally { Pop-Location }
        $files.Count | Should -BeGreaterThan 0 -Because 'a sweep over nothing proves nothing'

        $hits = foreach ($rel in $files) {
            $lines = [System.IO.File]::ReadAllLines((Join-Path $script:RepoRoot $rel))
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '(?i)claude\.build\.ledger') { "${rel}:$($i + 1): $($lines[$i].Trim())" }
            }
        }
        @($hits) | Should -BeNullOrEmpty -Because 'the ledger module ships from vendor/claude.agent.core'
    }
}
