#Requires -Version 7.4
<#
.SYNOPSIS
    The one way to script a text replacement in a tracked file: every old string must occur
    exactly once, and the line diff must be the one the caller declared, or nothing is written.

.DESCRIPTION
    Written for the defect in 23b1db9 (I12 PR 1), reproduced byte for byte in I13 PR 2. An
    inline edit loop meant to change ONE line of END_GOAL.md held its pairs as

        @{ F = 'END_GOAL.md'; P = @( @('<old>', '<new>') ) }

    and `@( @(a, b) )` is not an array holding one pair: the outer @() unrolls the inner array,
    so P was two STRINGS. `foreach ($p in $e.P)` then walked strings, and `$p[0]` / `$p[1]` were
    CHARACTERS: Replace('`', 'j') from the first string and Replace('a', ' ') from the second.
    658 lines changed where one was meant to. The anchor check passed, because a one-character
    anchor is almost always present. Every other file in that call had two or more pairs, which
    stay pairs, and was edited correctly. See DECISIONS.md and FINDINGS.md.

    This script closes each part of that:

      * Old and New are two parallel arrays, not a list of pairs. There is no pair shape to
        flatten, and their counts must match.
      * Every Old string must occur EXACTLY ONCE in the file. A stray character occurs
        hundreds of times and is refused. A deliberate repeat needs its own anchor.
      * The line diff (git diff --no-index --numstat) is measured on a temporary copy BEFORE
        the file is written, printed, and compared with -ExpectAdded / -ExpectDeleted. A
        mismatch writes nothing and exits 1.
      * Line endings follow the file: an Old or New written with LF is matched as CRLF in a
        CRLF working copy, so a correct anchor is not refused for its line endings. A UTF-8
        byte-order mark is kept if the file had one.

    tests/ScriptedEdit.Tests.ps1 runs 23b1db9's exact inputs through it on the clean parent.

.EXAMPLE
    pwsh -NoProfile -File scripts/Edit-Text.ps1 -Path END_GOAL.md `
        -Old 'the old line' -New 'the new line' -ExpectAdded 1 -ExpectDeleted 1
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string[]] $Old,
    [Parameter(Mandatory)] [AllowEmptyString()] [string[]] $New,
    [Parameter(Mandatory)] [int] $ExpectAdded,
    [Parameter(Mandatory)] [int] $ExpectDeleted
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # git diff exits 1 when files differ

function Stop-Edit([string]$Why) {
    [Console]::Error.WriteLine("Edit-Text: REFUSED, nothing written: $Why")
    exit 1
}

$full = (Resolve-Path -LiteralPath $Path).ProviderPath
if ($Old.Count -ne $New.Count) { Stop-Edit "$($Old.Count) old string(s) but $($New.Count) new string(s)" }

$bytes = [System.IO.File]::ReadAllBytes($full)
$bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
$utf8 = [System.Text.UTF8Encoding]::new($bom)
$text = $utf8.GetString($bytes, $(if ($bom) { 3 } else { 0 }), $bytes.Length - $(if ($bom) { 3 } else { 0 }))
$crlf = $text.Contains("`r`n")

$after = $text
for ($i = 0; $i -lt $Old.Count; $i++) {
    $o = $Old[$i]; $n = $New[$i]
    if ([string]::IsNullOrEmpty($o)) { Stop-Edit "old string $i is empty" }
    if ($crlf) {
        $o = $o.Replace("`r`n", "`n").Replace("`n", "`r`n")
        $n = $n.Replace("`r`n", "`n").Replace("`n", "`r`n")
    }
    $hits = ($after.Length - $after.Replace($o, '').Length) / $o.Length
    if ($hits -ne 1) {
        $shown = if ($o.Length -gt 60) { $o.Substring(0, 60) + '...' } else { $o }
        Stop-Edit "old string $i occurs $hits time(s), not exactly once: '$shown'"
    }
    $after = $after.Replace($o, $n)
}

# Measure on copies, before the real file is touched.
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("edit-text-" + [guid]::NewGuid().ToString('n'))
$null = New-Item -ItemType Directory -Path $tmp
try {
    $a = Join-Path $tmp 'before'; $b = Join-Path $tmp 'after'
    [System.IO.File]::WriteAllText($a, $text, $utf8)
    [System.IO.File]::WriteAllText($b, $after, $utf8)
    $numstat = @(& git -c core.autocrlf=false -c core.safecrlf=false diff --no-index --numstat -- $a $b) | Select-Object -First 1
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$added = 0; $deleted = 0
if ($numstat -match '^(\d+)\s+(\d+)\s') { $added = [int]$Matches[1]; $deleted = [int]$Matches[2] }

Write-Host ("Edit-Text: {0} line diff +{1} -{2} (expected +{3} -{4})" -f
    $Path, $added, $deleted, $ExpectAdded, $ExpectDeleted)

if ($added -ne $ExpectAdded -or $deleted -ne $ExpectDeleted) {
    Stop-Edit "the line diff is +$added -$deleted, the caller declared +$ExpectAdded -$ExpectDeleted"
}

$out = [System.Collections.Generic.List[byte]]::new()
if ($bom) { $out.AddRange([byte[]](0xEF, 0xBB, 0xBF)) }
$out.AddRange($utf8.GetBytes($after))
[System.IO.File]::WriteAllBytes($full, $out.ToArray())
exit 0
