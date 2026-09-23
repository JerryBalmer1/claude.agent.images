#Requires -Version 7.4
<#
    The trailer guard's exemption list.

    .continuity/trailer-grandfather.txt exempts, by exact full 40-character hash, commits that
    predate the guard and carry no `who:` trailer. They cannot be repaired - that means
    rewriting pushed history, and .continuity/forensic.jsonl cites hashes as evidence.

    IN THIS REPOSITORY THE LIST IS EMPTY, and the file is 0 bytes. The twenty-four commits it
    named in claude.pwsh.image.builder were not carried over at birth; every one of the seven
    commits here carries `who: claude`. The test that asserted the count of twenty-four was
    RETIRED on 2026-09-23 - forensic seq 8, subject prebirth-tests-retired - because a count of
    commits that are not in this tree has no falsifier in this tree. Its `Should -Exist` did
    not go with it: that one moved into the test below, because the file existing IS a fact
    about this tree, and without it a missing file would make both list tests below pass
    vacuously over an empty read.

    A list like that only stays honest if something constrains it. What is left is the
    anti-padding test (every entry genuinely lacks a trailer, so the list cannot be widened
    with compliant commits to make room) and the two falsifications (emptying the list turns
    the guard red, so "exempts some things" and "exempts everything" are distinguishable from
    the outside). The falsifications SKIP while the list exempts nothing in range - see the
    discovery block below - so on today's tree they prove nothing, and that is stated rather
    than relied on.

    NOTE ON RANGES, learned the expensive way in claude.agent.substrate. These run against
    `-Base origin/develop`, never full history with -IncludeMerges. On a pull request,
    actions/checkout hands you refs/pull/N/merge - a merge commit GitHub synthesises, which
    nobody wrote and which therefore has no trailer. A full-history run with merges included
    finds it and fails in CI while passing locally; worse, a test that EXPECTS failure then
    passes off that synthetic commit rather than off the thing it meant to catch.
#>

# DISCOVERY TIME, deliberately. -Skip is evaluated while Pester builds the tree, before any
# BeforeAll has run, so this cannot use $script:RepoRoot or the helper module and re-derives
# what it needs from $PSScriptRoot.
#
# WHAT THE TWO FALSIFICATION TESTS ACTUALLY NEED, measured rather than assumed. They remove the
# exemption list and require the guard to go red. That only proves something when the list is
# rescuing at least one commit IN THE RANGE. An empty range is the obvious case, but not the only
# one and not the one this repository is in: at 28134a4 the range held four commits, every one
# carrying who: claude, and the guard passed with an empty list because there was nothing for the
# list to have been hiding. The precondition is therefore the intersection, not the range size -
# the empty range falls out of it for free.
#
# Skipped, not passed. A test that cannot fail must not report green.
$discoveryRoot        = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$discoveryGrandfather = Join-Path $discoveryRoot '.continuity/trailer-grandfather.txt'

$discoveryExempt = @()
if (Test-Path -LiteralPath $discoveryGrandfather) {
    $discoveryExempt = @(Get-Content -LiteralPath $discoveryGrandfather |
                         ForEach-Object { ($_ -split '#')[0].Trim() } |
                         Where-Object { $_ -ne '' })
}

$discoveryRange = @()
try {
    $discoveryRange = @(& git -C $discoveryRoot log --format=%H --no-merges 'origin/develop..HEAD' 2>$null)
}
catch { $discoveryRange = @() }

# -ccontains: case-sensitive, full 40-char match, the same rule the guard itself applies.
$discoveryExemptInRange = @($discoveryExempt | Where-Object { $discoveryRange -ccontains $_ })
$NothingToFalsify       = ($discoveryExemptInRange.Count -eq 0)

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot    = Get-RepoRoot
    $script:Guard       = Join-Path $script:RepoRoot 'scripts/ci/Test-Trailers.ps1'
    $script:Grandfather = Join-Path $script:RepoRoot '.continuity/trailer-grandfather.txt'

    function script:Get-GrandfatherHashes {
        param([string]$Path = $script:Grandfather)
        return @(Get-Content -LiteralPath $Path |
                 ForEach-Object { ($_ -split '#')[0].Trim() } |
                 Where-Object { $_ -ne '' })
    }

    function script:Invoke-TrailerGuard {
        param([string[]]$Arguments)
        $PSNativeCommandUseErrorActionPreference = $false
        $out = & pwsh -NoProfile -File $script:Guard @Arguments 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = (@($out) -join "`n") }
    }
}

Describe 'the trailer grandfather list' {

    It 'names every hash in full, and every one is a real commit here' {
        # A shortened hash would turn an exact-match exemption into a prefix match on somebody
        # else's commit.
        #
        # THE -Exist CHECK IS LOAD-BEARING AND IS NOT DECORATION. It is the one assertion kept
        # back from the retired count test. Get-Content on a missing path yields nothing, the
        # foreach below never runs, and this test plus the anti-padding one would both report
        # green over a file somebody deleted. See the header.
        $script:Grandfather | Should -Exist
        $PSNativeCommandUseErrorActionPreference = $false
        foreach ($h in script:Get-GrandfatherHashes) {
            $h | Should -MatchExactly '^[0-9a-f]{40}$'
            (& git -C $script:RepoRoot cat-file -t $h 2>&1).Trim() | Should -Be 'commit' -Because "$h must exist in this repository"
        }
    }

    It 'exempts only commits that genuinely lack a trailer' {
        # THE ANTI-PADDING TEST. An exemption for a commit that already complies is dead weight,
        # and it is also the shape of a list someone has quietly widened: add a few compliant
        # hashes, nobody notices, then add one that is not.
        $PSNativeCommandUseErrorActionPreference = $false
        foreach ($h in script:Get-GrandfatherHashes) {
            $who = (& git -C $script:RepoRoot log -1 --format='%(trailers:key=who,valueonly)' $h | Out-String).Trim()
            $who | Should -BeNullOrEmpty -Because "$($h.Substring(0,8)) already carries 'who: $who' and does not need exempting"
        }
    }
}

Describe 'the trailer guard over the pull-request range' {

    It 'passes, using the exemption' {
        $r = script:Invoke-TrailerGuard -Arguments @('-Base', 'origin/develop', '-Head', 'HEAD')
        if ($r.ExitCode -ne 0) { Write-Host $r.Output }
        $r.ExitCode | Should -Be 0
    }

    It 'rejects a Co-Authored-By trailer, which the CI port would otherwise have dropped' -Skip:$NothingToFalsify {
        # develop's ci.yml had a dedicated "no Co-Authored-By" step. Porting substrate's CI
        # wholesale would have lost it silently, so it is folded into the trailer guard. This
        # proves it can actually fail: an empty exemption list means the eight run-01 commits
        # that DO carry Co-Authored-By are no longer exempt, and the guard must say so by name.
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "gf-coauth-$([guid]::NewGuid()).txt"
        Set-Content -LiteralPath $tmp -Value '' -Encoding utf8
        try {
            $r = script:Invoke-TrailerGuard -Arguments @('-Base', 'origin/develop', '-Head', 'HEAD', '-GrandfatherPath', $tmp)
            $r.ExitCode | Should -Be 1
            $r.Output   | Should -Match 'COAUTH' -Because 'the guard must name Co-Authored-By as the reason, not just fail'
        }
        finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'fails with an empty exemption list, so the list is load-bearing rather than decorative' -Skip:$NothingToFalsify {
        # THE FALSIFICATION. A guard that exempted everything would pass the test above forever.
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "gf-empty-$([guid]::NewGuid()).txt"
        Set-Content -LiteralPath $tmp -Value '' -Encoding utf8
        try {
            $r = script:Invoke-TrailerGuard -Arguments @('-Base', 'origin/develop', '-Head', 'HEAD', '-GrandfatherPath', $tmp)
            $r.ExitCode | Should -Be 1
            $r.Output   | Should -Match 'MISS'
        }
        finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}
