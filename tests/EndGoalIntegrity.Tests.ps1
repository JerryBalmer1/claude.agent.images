#Requires -Version 7.4

<#
    Every run section of END_GOAL.md stays readable, not only the newest.

    Goal.Update checks the NEWEST section's required fields and nothing older. On 2026-09-24,
    commit 23b1db9 rewrote 658 older lines of this file - every 'a' dropped, every backtick turned
    into 'j' - while the change it meant to make was one line, and the build stayed green for four
    pull requests because the newest section was always intact. Forensic chain seq 38.

    So this checks the same required labels in EVERY '## <date> <sha> run-01' section, plus the
    file's own opening sentence. It fails on damage anywhere in the record, not just at the top.
#>

BeforeDiscovery {
    $root = Split-Path -Parent $PSScriptRoot
    $lines = [System.IO.File]::ReadAllLines((Join-Path $root 'END_GOAL.md'))
    $script:Sections = @(
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^##\s+(\d{4}-\d{2}-\d{2})\s+([0-9a-f]{7,40})\s+run-01\s*$') {
                $end = $lines.Count
                for ($j = $i + 1; $j -lt $lines.Count; $j++) { if ($lines[$j] -match '^##\s') { $end = $j; break } }
                @{ Header = $lines[$i].Trim(); Line = $i + 1; Text = ($lines[$i..($end - 1)] -join "`n") }
            }
        }
    )
}

BeforeAll {
    $script:Required = @('Changed', 'Tested', 'Failed', 'Missing', 'Blockers', 'Ledger head hash', 'Assessment hash')
}

Describe 'END_GOAL.md is intact, every section of it' {
    It 'opens with its own first sentence' {
        $first = [System.IO.File]::ReadAllLines((Join-Path (Split-Path -Parent $PSScriptRoot) 'END_GOAL.md'))[2]
        $first | Should -BeExactly 'The state of this repository, recorded by the run that changed it.'
    }

    # Discovery-phase variables do not survive into the run phase; the count is handed in as data.
    It 'has run sections to check (<Count> found)' -ForEach @(@{ Count = $script:Sections.Count }) {
        $Count | Should -BeGreaterThan 5
    }

    It '<Header> (line <Line>) carries every required field' -ForEach $script:Sections {
        $missing = foreach ($label in $script:Required) {
            if ($Text -notmatch ('(?im)^\s*(?:[-*]\s*)?\**\s*' + [regex]::Escape($label) + '\s*\**\s*:')) { $label }
        }
        @($missing) | Should -BeNullOrEmpty -Because 'a section missing its labels is a damaged record'
    }
}
