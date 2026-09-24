#Requires -Version 7.4

<#
    This repository is public. No tracked file outside .continuity/ may carry a local user path,
    an email address, a token or private key, or the name of the private origin repository.

    .continuity/ is excluded because forensic records are never edited: the hits inside them are
    listed in DECISIONS.md and on the chain at seq 29 and seq 30, not rewritten. vendor/ is a
    submodule and belongs to another repository.

    Every pattern is assembled from fragments, so this file cannot match itself and does not
    need an exemption of its own.
#>

BeforeDiscovery {
    $script:Patterns = @(
        @{ Kind = 'local user path'; Regex = '(?i)[A-Z]:[\\/]+' + 'Us' + 'ers[\\/]|/' + 'ho' + 'me/' }
        @{ Kind = 'email address';   Regex = '[A-Za-z0-9._%+-]+' + '@' + '[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' }
        @{ Kind = 'token or key';    Regex = 'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIV' + 'ATE KEY-----|sk-ant-[A-Za-z0-9_-]{10,}|xox[abprs]-[A-Za-z0-9-]{10,}' }
        @{ Kind = 'private origin repository name'; Regex = '(?i)\bsub' + 'strate\b' }
    )
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $root = Get-RepoRoot
    Push-Location $root
    try { $tracked = @(git -c core.quotepath=off ls-files) } finally { Pop-Location }
    $script:Files = @($tracked | Where-Object { $_ -notmatch '^(\.continuity|vendor)/' -and $_ -ne 'vendor/claude.agent.core' })
    $script:Text = @{}
    foreach ($rel in $script:Files) {
        $full = Join-Path $root $rel
        if (Test-Path -LiteralPath $full -PathType Leaf) { $script:Text[$rel] = [System.IO.File]::ReadAllLines($full) }
    }
}

Describe 'Public hygiene: tracked files outside .continuity/' {
    It 'has files to scan' {
        $script:Text.Count | Should -BeGreaterThan 50 -Because 'a scan over nothing proves nothing'
    }

    It 'carries no <Kind>' -ForEach $script:Patterns {
        $hits = foreach ($rel in ($script:Text.Keys | Sort-Object)) {
            $lines = $script:Text[$rel]
            for ($i = 0; $i -lt $lines.Count; $i++) {
                foreach ($m in [regex]::Matches($lines[$i], $Regex)) { "${rel}:$($i + 1): $($m.Value)" }
            }
        }
        @($hits) | Should -BeNullOrEmpty
    }
}
