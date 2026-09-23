#Requires -Version 7.4
<#
    The trailer guard's exemption list.

    .continuity/trailer-grandfather.txt names twenty-four commits that predate the guard and carry
    no `who:` trailer. They cannot be repaired - that means rewriting pushed history, and
    .continuity/forensic.jsonl cites several of these hashes as evidence.

    A list like that only stays honest if something counts it. The load-bearing tests here are
    the last two: that every entry genuinely lacks a trailer (so the list cannot be padded with
    compliant commits to make room), and that emptying the list turns the guard red (so
    "exempts twenty-four things" and "exempts everything" are distinguishable from the outside).

    NOTE ON RANGES, learned the expensive way in claude.agent.substrate. These run against
    `-Base origin/develop`, never full history with -IncludeMerges. On a pull request,
    actions/checkout hands you refs/pull/N/merge - a merge commit GitHub synthesises, which
    nobody wrote and which therefore has no trailer. A full-history run with merges included
    finds it and fails in CI while passing locally; worse, a test that EXPECTS failure then
    passes off that synthetic commit rather than off the thing it meant to catch.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot    = Get-RepoRoot
    $script:Guard       = Join-Path $script:RepoRoot 'scripts/ci/Test-Trailers.ps1'
    $script:Grandfather = Join-Path $script:RepoRoot '.continuity/trailer-grandfather.txt'
    $script:Expected    = 24

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

    It 'has exactly the twenty-four commits the two measurements derived' {
        $script:Grandfather | Should -Exist
        (script:Get-GrandfatherHashes).Count | Should -Be $script:Expected
    }

    It 'names every hash in full, and every one is a real commit here' {
        # A shortened hash would turn an exact-match exemption into a prefix match on somebody
        # else's commit.
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

    It 'rejects a Co-Authored-By trailer, which the CI port would otherwise have dropped' {
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

    It 'fails with an empty exemption list, so the list is load-bearing rather than decorative' {
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
