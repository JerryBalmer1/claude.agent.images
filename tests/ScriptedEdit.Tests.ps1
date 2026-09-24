#Requires -Version 7.4

<#
    The root cause of 23b1db9, pinned, and the guard that would have caught it at edit time.

    23b1db9 (I12 PR 1) was meant to change one line of END_GOAL.md and changed 658: every 'a'
    became a space and every backtick became 'j'. The command that made the edit is in the I12
    session transcript. Its END_GOAL entry was

        @{ F = 'END_GOAL.md'; P = @( @('<old>', '<new>') ) }

    and `@( @(a, b) )` unrolls to two strings, so the loop's `$p[0]` / `$p[1]` were characters.
    The first Describe re-runs that entry and loop on the clean parent, 23b1db9~1's blob, and
    gets 23b1db9's blob byte for byte. The second runs the same inputs through
    scripts/Edit-Text.ps1, which refuses them and writes nothing.

    The old line names a personal address, so it is read out of the parent blob at run time
    rather than written here: tests/PublicHygiene.Tests.ps1 fails on an address in a tracked file.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    $script:EditText = Join-Path $script:RepoRoot 'scripts' 'Edit-Text.ps1'

    $script:CleanBlob = 'b017750dbd32826aa54e0c534a2aee47d4be7378'   # 23b1db9~1:END_GOAL.md
    $script:BadBlob = '54901e2a49344db06f6f0b626a0b81a6b129ef51'     # 23b1db9:END_GOAL.md

    # Raw blob bytes, not decoded text: the comparison below is by git blob id.
    function Save-Blob([string]$Blob, [string]$To) {
        $psi = [System.Diagnostics.ProcessStartInfo]::new('git')
        foreach ($a in @('-C', $script:RepoRoot, 'cat-file', 'blob', $Blob)) { $psi.ArgumentList.Add($a) }
        $psi.RedirectStandardOutput = $true
        $psi.UseShellExecute = $false
        $p = [System.Diagnostics.Process]::Start($psi)
        $fs = [System.IO.File]::Create($To)
        try { $p.StandardOutput.BaseStream.CopyTo($fs) } finally { $fs.Dispose() }
        $p.WaitForExit()
        if ($p.ExitCode -ne 0) { throw "git cat-file blob $Blob exited $($p.ExitCode)" }
    }

    function Get-BlobId([string]$File) {
        (& git -C $script:RepoRoot hash-object --no-filters -- $File).Trim()
    }

    $script:Box = New-LeashSandbox
    $script:Parent = Join-Path $script:Box.Root 'parent.md'
    Save-Blob -Blob $script:CleanBlob -To $script:Parent

    # The two strings 23b1db9 meant as one pair. Old is read from the parent, New is verbatim.
    $m = [regex]::Match([System.IO.File]::ReadAllText($script:Parent), '`[^`]+` as the author of every human commit')
    $script:IntendedOld = $m.Value
    $script:IntendedNew = 'a personal gmail address (removed from this line 2026-09-24, I12 PR 1; it remains in git history) as the author of every human commit'
}

AfterAll { Remove-Item -LiteralPath $script:Box.Root -Recurse -Force -ErrorAction SilentlyContinue }

Describe '23b1db9, reproduced' {
    It 'starts from the clean parent, which holds the intended anchor once' {
        Get-BlobId $script:Parent | Should -Be $script:CleanBlob
        $script:IntendedOld | Should -Not -BeNullOrEmpty
    }

    It 'turns the clean parent into 23b1db9''s blob with the transcript''s entry and loop' {
        $work = Join-Path $script:Box.Root 'repro'
        $null = New-Item -ItemType Directory -Path $work -Force
        Copy-Item -LiteralPath $script:Parent -Destination (Join-Path $work 'END_GOAL.md')

        Push-Location $work
        try {
            # From the I12 transcript, the END_GOAL entry and the loop, unchanged but for the
            # old string, which is the same value read from the parent.
            $edits = @(
                @{ F = 'END_GOAL.md'; P = @( @($script:IntendedOld, $script:IntendedNew) ) }
            )
            foreach ($e in $edits) { $full = Resolve-Path $e.F; $x = [System.IO.File]::ReadAllText($full); foreach ($p in $e.P) { if (-not $x.Contains($p[0])) { throw "anchor missing in $($e.F): $($p[0])" }; $x = $x.Replace($p[0], $p[1]) }; [System.IO.File]::WriteAllText($full, $x) }

            $edits[0].P.Count | Should -Be 2 -Because '@( @(a, b) ) unrolls to two strings'
            $edits[0].P[0] | Should -BeOfType [string]
        }
        finally { Pop-Location }

        Get-BlobId (Join-Path $work 'END_GOAL.md') | Should -Be $script:BadBlob
    }

    It 'keeps the pair when it is written @( ,@(a, b) )' {
        $P = @( , @($script:IntendedOld, $script:IntendedNew) )
        $P.Count | Should -Be 1
        $P[0][0] | Should -BeExactly $script:IntendedOld
    }
}

Describe 'scripts/Edit-Text.ps1 refuses what 23b1db9 did, and does what it meant' {
    BeforeEach {
        $script:Target = Join-Path $script:Box.Root 'END_GOAL.md'
        Copy-Item -LiteralPath $script:Parent -Destination $script:Target -Force
    }

    It 'refuses 23b1db9''s effective replacements and writes nothing' {
        # What the loop actually applied: backtick -> j, then a -> space.
        & $script:EditText -Path $script:Target -Old '`', 'a' -New 'j', ' ' -ExpectAdded 1 -ExpectDeleted 1 2>$null
        $LASTEXITCODE | Should -Be 1
        Get-BlobId $script:Target | Should -Be $script:CleanBlob
    }

    It 'refuses a correct anchor when the declared line diff is wrong, and writes nothing' {
        & $script:EditText -Path $script:Target -Old $script:IntendedOld -New $script:IntendedNew -ExpectAdded 0 -ExpectDeleted 0 2>$null
        $LASTEXITCODE | Should -Be 1
        Get-BlobId $script:Target | Should -Be $script:CleanBlob
    }

    It 'refuses when old and new do not pair up' {
        & $script:EditText -Path $script:Target -Old $script:IntendedOld, 'x' -New $script:IntendedNew -ExpectAdded 1 -ExpectDeleted 1 2>$null
        $LASTEXITCODE | Should -Be 1
        Get-BlobId $script:Target | Should -Be $script:CleanBlob
    }

    It 'makes the intended edit: one line out, one line in' {
        & $script:EditText -Path $script:Target -Old $script:IntendedOld -New $script:IntendedNew -ExpectAdded 1 -ExpectDeleted 1
        $LASTEXITCODE | Should -Be 0

        $PSNativeCommandUseErrorActionPreference = $false   # diff --no-index exits 1 on a difference
        $numstat = @(& git -c core.autocrlf=false -c core.safecrlf=false diff --no-index --numstat -- $script:Parent $script:Target) | Select-Object -First 1
        $numstat | Should -Match '^1\s+1\s'
        [System.IO.File]::ReadAllText($script:Target) | Should -Match ([regex]::Escape($script:IntendedNew))
    }

    It 'matches an LF anchor in a CRLF copy, and keeps CRLF' {
        $crlf = Join-Path $script:Box.Root 'crlf.md'
        [System.IO.File]::WriteAllText($crlf, "one`r`ntwo`r`nthree`r`n")
        & $script:EditText -Path $crlf -Old "one`ntwo" -New "one`nTWO" -ExpectAdded 1 -ExpectDeleted 1
        $LASTEXITCODE | Should -Be 0
        [System.IO.File]::ReadAllText($crlf) | Should -BeExactly "one`r`nTWO`r`nthree`r`n"
    }
}
