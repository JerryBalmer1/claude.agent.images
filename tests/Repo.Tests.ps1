#Requires -Version 7.4
<#
    Assertions about the shape of the repository, from the cleanup pass: BLOCKER-11 (one
    END_GOAL.md), CODEOWNERS, and the sweep for stale BREADCRUMBS paths.

    RETIRED, 2026-09-23. Three tests here asserted the per-agent scaffold that this repository
    did not inherit: the birth pruned it, so nothing in this tree could ever make them go
    green and nothing in this tree could make them go red either. Forensic seq 8, subject
    prebirth-tests-retired, names all three and the birth record they trace to. They were
    removed, not skipped and not rewritten to pass: an assertion with no falsifier here is not
    a test. What survives below is the one assertion that still has one - a content sweep over
    tracked files, which any future commit can falsify by reintroducing the old path.

    These are measured against the GIT INDEX, not the working tree. `git ls-files` is what the
    repository actually contains; a Get-ChildItem sweep also finds untracked scratch, build
    output and anything an agent forgot to clean up, and would report a state nobody could
    reproduce from a clone.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot

    function script:Get-TrackedFiles {
        $PSNativeCommandUseErrorActionPreference = $false
        return @(& git -C $script:RepoRoot ls-files)
    }

    # ASSEMBLED FROM FRAGMENTS, NEVER WRITTEN AS ONE LITERAL. This file asserts that no tracked
    # file still contains the pre-move BREADCRUMBS path; spelled out here it would match itself
    # and the assertion could never go green. Same technique, same reason, as the fake tokens in
    # tests/Env.Tests.ps1. Do not join these into a plain string.
    $script:OldCrumbPath = 'docs' + '/' + 'BREADCRUMBS' + '.md'
}

Describe 'BLOCKER-11: exactly one END_GOAL.md' {

    It 'has exactly one tracked file whose LEAF NAME is exactly END_GOAL.md' {
        # EXACT LEAF NAME, never a glob. This is the whole trap and it is worth spelling out:
        #
        #   git ls-files | grep END_GOAL   ->  END_GOAL.md
        #                                      docs/plans/2026-09-21-oneshot/END_GOAL.DRAFT.md
        #
        # A `*END_GOAL*` assertion matches the DRAFT too, and the run order forbids deleting it.
        # Written as a glob, this test could never go green without destroying evidence.
        $exact = @(script:Get-TrackedFiles | Where-Object { (Split-Path $_ -Leaf) -ceq 'END_GOAL.md' })
        $exact.Count | Should -Be 1 -Because "found: $($exact -join ', ')"
        $exact[0] | Should -Be 'END_GOAL.md' -Because 'the load-bearing one is at the root; Goal.Update reads it'
    }

    It 'still carries the draft it is forbidden to delete' {
        # The other half. A test that only counts can be satisfied by deleting the wrong file.
        (script:Get-TrackedFiles) | Should -Contain 'docs/plans/2026-09-21-oneshot/END_GOAL.DRAFT.md'
    }

    It 'kept Grok''s section verbatim, under an attribution heading' {
        # docs/END_GOAL.md was deleted; its unique section moved to the root file unedited.
        # Deleting Grok's words would also make this test pass if it only checked the count.
        $text = [System.IO.File]::ReadAllText((Join-Path $script:RepoRoot 'END_GOAL.md'))
        $text | Should -Match 'Merged from docs/END_GOAL\.md \(Grok, b0232b8\)'
        $text | Should -Match 'Grok review of oneshot'
        $text | Should -Match 'pending-exports'
    }
}

Describe 'CODEOWNERS' {

    It 'exists at the repository root and names the owner' {
        $p = Join-Path $script:RepoRoot 'CODEOWNERS'
        $p | Should -Exist
        (([System.IO.File]::ReadAllText($p)).Trim()) | Should -Be '* @JerryBalmer1'
    }
}

Describe 'stale BREADCRUMBS references' {

    It 'has no reference left pointing at the old path' {
        # THE OLD PATH IS ASSEMBLED AT RUNTIME AND NEVER WRITTEN AS ONE LITERAL IN THIS FILE.
        # Do not "tidy" $script:OldCrumbPath into a plain string - that is what breaks it.
        #
        # Written out in full, this test sweeps every tracked file for the old path and finds
        # ITSELF, because it is a tracked file containing the old path. It passed when first
        # run only because it was still untracked at that moment, and went red on the runner
        # the instant it was committed. Same class as FINDING-M6, and the same trap the run
        # order names for the 7.6 grep: a counter that counts itself.
        #
        # tests/Env.Tests.ps1 already does this for fake tokens, for the same reason - a file
        # that must not contain a string cannot contain that string, including in its own
        # assertions and comments.
        #
        # The plan folders are excluded because docs/plans/2026-09-21-oneshot/ASSESSMENT.md:406
        # carries the pre-move path inside a table of fields it inherited, and rewriting a plan to
        # agree with a later decision is how evidence stops being evidence.
        #
        # The exclusion used to be justified as "FROZEN RECORDS of what was true when they were
        # written: several are covered by a HASHES.txt". RETIRED 2026-09-23. Measured: no
        # HASHES.txt is tracked anywhere in this repository. One exists in
        # vendor/claude.agent.core at pin a68664e, over nine artefacts belonging to core and none
        # belonging to this tree, so it covers nothing here. The other half of that claim is true
        # and is kept - the forensic chain cites docs/plans paths at seq 1, seq 5 and seq 9.
        #
        # Nor are plans here frozen: e221ddb edited four sites across these two files. The rule
        # actually in force is the one the Describe at the end of this file asserts.
        $stale = @(script:Get-TrackedFiles |
                   Where-Object { $_ -match '\.(md|ps1|yml)$' } |
                   Where-Object { $_ -notmatch '^docs/plans/' -and $_ -notmatch '^vendor/' } |
                   Where-Object { (Get-Content -LiteralPath (Join-Path $script:RepoRoot $_) -Raw) -match ([regex]::Escape($script:OldCrumbPath)) })
        $stale.Count | Should -Be 0 -Because "these still point at the old path: $($stale -join ', ')"
    }
}

Describe 'docs/plans: annotated in past tense, not frozen' {

    It 'still carries every measurement its plans recorded' {
        # THE RULE IN FORCE, and it is not the one the sweep above used to claim. A plan may be
        # annotated in past tense with a date: e221ddb did exactly that at four sites on
        # 2026-09-23, moving a retired blocker into the past and appending dated notes. What it
        # did not do, and what nothing here may do, is change a number a plan RECORDED. The
        # measurement is the evidence; the tense wrapped around it is prose.
        #
        # So this pins the measurements and nothing else. A dated annotation leaves every pin in
        # place and passes. An edit that rewrites a recorded value removes its pin and fails,
        # naming the file and the value that went missing.
        #
        # A pinned LIST and deliberately not a hash over the whole file: a hash would forbid the
        # annotation as well, which is the rule this repository does NOT have. There is also no
        # HASHES.txt here to lean on - the only one reachable is in vendor/claude.agent.core at
        # pin a68664e and covers nine artefacts belonging to core, none of these.
        $pins = @(
            @{ File = 'docs/plans/2026-09-21-oneshot/END_GOAL.DRAFT.md'; Value = 'passed=109 failed=0 skipped=0' }
            @{ File = 'docs/plans/2026-09-21-oneshot/END_GOAL.DRAFT.md'; Value = '06e738d' }
            @{ File = 'docs/plans/2026-09-21-oneshot/END_GOAL.DRAFT.md'; Value = 'a476fdfdfd48f655af413d2057e8ff4f58966aa7f653f64963500f724706a140' }
            @{ File = 'docs/plans/2026-09-21-oneshot/END_GOAL.DRAFT.md'; Value = 'Ledger.psm1:298' }
            @{ File = 'docs/plans/2026-09-21-oneshot/END_GOAL.DRAFT.md'; Value = 'Ledger.psm1:1121' }
            @{ File = 'docs/plans/2026-09-21-oneshot/ASSESSMENT.md'; Value = 'Ledger.psm1:298' }
            @{ File = 'docs/plans/2026-09-21-oneshot/ASSESSMENT.md'; Value = 'Ledger.psm1:1121' }
            @{ File = 'docs/plans/2026-09-21-oneshot/ASSESSMENT.md'; Value = 'a476fdfdfd48f655af413d2057e8ff4f58966aa7f653f64963500f724706a140' }
        )

        # Read as bytes-to-text once per file, not once per pin, and report EVERY missing pin in
        # one failure. A gate that stops at the first one makes the reader run it again to learn
        # what else moved.
        $texts = @{}
        foreach ($file in ($pins.File | Sort-Object -Unique)) {
            $full = Join-Path $script:RepoRoot $file
            $full | Should -Exist -Because 'a pinned plan cannot be deleted either'
            $texts[$file] = [System.IO.File]::ReadAllText($full)
        }

        $gone = @(foreach ($pin in $pins) {
            if (-not $texts[$pin.File].Contains($pin.Value)) { "$($pin.File): $($pin.Value)" }
        })

        $gone.Count | Should -Be 0 -Because ('a recorded measurement was changed, not annotated: ' + ($gone -join '; '))
    }
}
