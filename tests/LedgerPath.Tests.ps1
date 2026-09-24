#Requires -Version 7.4

<#
    The ledger module is claude.agent.core's, and nothing that ships may still point at
    claude.build.ledger.

    Found by claude.agent.tools T0 (corpus/images-249752d.jsonl): src/LedgerReceipt.ps1:103 named
    /opt/leash/vendor/claude.build.ledger/..., a path no image has ever created, and :104 built the
    same dead host path out of Join-Path pieces. The inspector's dead-vendor-path rule caught :103
    and missed :104, because Join-Path splits the path - so the sweep below matches the NAME in
    any form, not the slash-joined literal. Forensic chain seq 24.

    The behavioural test calls Invoke-LedgerBootVerify against a real chain written by core's
    Add-LedgerRecord and asserts the answer came from core's Get-LedgerVerify. It runs in a child
    pwsh, so LEDGER_DIR never leaks into this session.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
}

Describe 'No shipped file points at claude.build.ledger' {
    # The five places the packet names. images/developer/Dockerfile is the developer image's
    # Dockerfile and copies the same module, so it is swept too.
    It 'finds claude.build.ledger in no tracked file under src/, hooks/, scripts/, entrypoint.ps1 or a Dockerfile' {
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

Describe 'Invoke-LedgerBootVerify verifies through core' -Tag 'Ledger' {
    BeforeAll {
        $script:Box = New-LeashSandbox
        $script:Driver = Join-Path $script:Box.Root 'drive.ps1'
        $receipt = Join-Path $script:RepoRoot 'src' 'LedgerReceipt.ps1'
        [System.IO.File]::WriteAllText($script:Driver, (@(
                    '#Requires -Version 7.4'
                    ". '$receipt'"
                    'Invoke-LedgerBootVerify | ConvertTo-Json -Compress -Depth 5'
                ) -join "`n"))

        Import-Module (Get-LedgerManifestPath) -Force
        $script:Written = Add-LedgerRecord -Path $script:Box.LedgerPath -Attempt 1 -Validator 'boot-verify-test' `
            -Mode 'Enforce' -Model 'test/boot/allow' -Sha256 ('0' * 64)
    }

    AfterAll { Remove-LeashSandbox -Root $script:Box.Root }

    It 'finds core''s module, verifies the chain with Get-LedgerVerify, and does not fall back' {
        $r = Invoke-LeashScript -Path $script:Driver -Environment @{ LEDGER_DIR = $script:Box.LedgerDir }
        $r.ExitCode | Should -Be 0 -Because "stderr was: $($r.StdErr)"
        $v = ConvertFrom-JsonSafe -Text $r.StdOut

        $v.PSObject.Properties.Name | Should -Not -Contain 'Mode' -Because 'Mode=sentinel-jsonl means no ledger module was found and the fallback ran'
        $v.Ok | Should -BeTrue
        $v.Count | Should -Be 1
        $v.LastSelf | Should -BeExactly $script:Written.Self
    }
}
