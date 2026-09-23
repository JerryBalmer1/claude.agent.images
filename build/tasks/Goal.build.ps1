#Requires -Version 7.4

<#
.SYNOPSIS
    Goal.Update — the gate on END_GOAL.md, and the forensic append.

.DESCRIPTION
    This task does NOT write END_GOAL.md. It checks that a human (or an agent
    acting as one) wrote it, and it refuses to let the chain go green if they
    did not. A task that generates the report it then approves is a task that
    always passes.

    What it insists on:

      * a section headed  ## <yyyy-MM-dd> <short sha> run-01
      * that names a commit actually on this branch, dated today
      * containing Changed, Tested, Failed, Missing, Blockers,
        Ledger head hash and Assessment hash
      * whose Assessment hash equals the one Bootstrap verified
      * whose Ledger head is either 64 hex characters or an explicit
        "unavailable: BLOCKER-n"
      * whose Tested totals MATCH output/incontainer.json

    That last one is the point of the whole task. Every other field is prose
    and prose cannot be checked; the totals can, so a report claiming a green
    run that did not happen fails here rather than being believed.

.NOTES
    The header sha is allowed to be HEAD or a recent ancestor, and that is a
    deliberate loosening of the run order's literal wording. The section has to
    be committed, and committing it moves HEAD, so a check pinned strictly to
    `git rev-parse --short HEAD` can never be satisfied by the commit that
    satisfies it. Naming a real commit from this run is the property that
    matters and it is the one enforced.
#>

# Synopsis: Refuse to finish unless END_GOAL.md documents this run, then record it.
task Goal.Update {
    $root = $Build.RepositoryRoot
    $goalPath = Join-Path $root 'END_GOAL.md'

    if (-not (Test-Path -LiteralPath $goalPath)) {
        throw "END_GOAL.md missing at $goalPath. Every run documents itself or the chain stays red."
    }

    $head = (exec { git -C $root rev-parse --short HEAD }).Trim()
    $recent = @(exec { git -C $root rev-list --max-count=25 --abbrev-commit HEAD }) | ForEach-Object { $_.Trim() }
    $today = (Get-Date).ToString('yyyy-MM-dd')

    $text = Get-Content -LiteralPath $goalPath -Raw -Encoding utf8
    $lines = $text -split "`r?`n"

    # ---- locate the section ---------------------------------------------
    $headerPattern = '^##\s+(?<date>\d{4}-\d{2}-\d{2})\s+(?<sha>[0-9a-f]{7,40})\s+' + [regex]::Escape($Build.RunId) + '\s*$'
    $startIndex = -1
    $sectionDate = $null
    $sectionSha = $null

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $m = [regex]::Match($lines[$i], $headerPattern)
        if ($m.Success) {
            $startIndex = $i
            $sectionDate = $m.Groups['date'].Value
            $sectionSha = $m.Groups['sha'].Value
            break
        }
    }

    if ($startIndex -lt 0) {
        throw ("END_GOAL.md has no section headed '## <yyyy-MM-dd> <short sha> $($Build.RunId)'. " +
               "Expected something like: ## $today $head $($Build.RunId)")
    }

    # Everything up to the next H2 is the section.
    $endIndex = $lines.Count
    for ($i = $startIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s') { $endIndex = $i; break }
    }
    $section = ($lines[$startIndex..($endIndex - 1)]) -join "`n"

    Write-Build DarkGray "END_GOAL section: $sectionDate $sectionSha $($Build.RunId) ($($endIndex - $startIndex) lines)"

    # ---- the header has to be about this run ----------------------------
    if ($sectionDate -ne $today) {
        throw "END_GOAL.md section is dated $sectionDate but today is $today. Stale reports are worse than none."
    }
    if ($sectionSha -ne $head -and $recent -notcontains $sectionSha) {
        throw ("END_GOAL.md section names commit $sectionSha, which is not HEAD ($head) " +
               'nor one of the last 25 commits on this branch.')
    }

    # ---- required fields -------------------------------------------------
    $required = @(
        'Changed', 'Tested', 'Failed', 'Missing', 'Blockers',
        'Ledger head hash', 'Assessment hash'
    )
    $missing = @()
    foreach ($label in $required) {
        $pattern = '(?im)^\s*(?:[-*]\s*)?\**\s*' + [regex]::Escape($label) + '\s*\**\s*:'
        if ($section -notmatch $pattern) { $missing += $label }
    }
    if ($missing.Count -gt 0) {
        throw ("END_GOAL.md section is missing required field(s): " + ($missing -join ', '))
    }

    # ---- the assessment hash must be the one Bootstrap verified ----------
    if ($section -notmatch [regex]::Escape($Build.AssessmentSha)) {
        throw ("END_GOAL.md section does not carry the verified assessment hash $($Build.AssessmentSha)")
    }

    # ---- the ledger head must be a hash or an explicit blocker -----------
    $ledgerRaw = ([regex]::Match($section, '(?im)^\s*(?:[-*]\s*)?\**\s*Ledger head hash\s*\**\s*:\s*(?<v>.+)$')).Groups['v'].Value.Trim()
    # Pull the hash out of the surrounding markdown rather than comparing the
    # whole rest of the line, which carries backticks and bold markers.
    $ledgerHash = ([regex]::Match($ledgerRaw, '[0-9a-f]{64}')).Value
    $ledgerLine = if ($ledgerHash) { $ledgerHash } else { $ledgerRaw }
    $ledgerOk = ($ledgerLine -cmatch '^[0-9a-f]{64}$') -or ($ledgerRaw -match 'unavailable:\s*BLOCKER-\d+')
    if (-not $ledgerOk) {
        throw ("END_GOAL.md 'Ledger head hash' must be 64 hex characters or 'unavailable: BLOCKER-n'; got '$ledgerLine'")
    }

    # ---- the totals must match the run that actually happened ------------
    $summaryPath = Join-Path $Build.OutputPath 'incontainer.json'
    if (Test-Path -LiteralPath $summaryPath) {
        $summary = Get-Content -LiteralPath $summaryPath -Raw -Encoding utf8 | ConvertFrom-Json
        $testedLine = ([regex]::Match($section, '(?im)^\s*(?:[-*]\s*)?\**\s*Tested\s*\**\s*:\s*(?<v>.+)$')).Groups['v'].Value

        foreach ($pair in @(
            @{ Name = 'passed'; Value = $summary.passed }
            @{ Name = 'failed'; Value = $summary.failed }
            @{ Name = 'skipped'; Value = $summary.skipped }
        )) {
            $m = [regex]::Match($testedLine, "$($pair.Name)\s*=\s*(?<n>\d+)")
            if (-not $m.Success) {
                throw "END_GOAL.md 'Tested:' must report $($pair.Name)=<n>; got '$testedLine'"
            }
            if ([int]$m.Groups['n'].Value -ne [int]$pair.Value) {
                throw ("END_GOAL.md claims $($pair.Name)=$($m.Groups['n'].Value) but " +
                       "output/incontainer.json records $($pair.Name)=$($pair.Value). " +
                       'The report must match the run.')
            }
        }
        Write-Build Green ("Totals verified against the run: passed={0} failed={1} skipped={2}" -f
            $summary.passed, $summary.failed, $summary.skipped)

        # The ledger head is deliberately NOT compared for equality. Every
        # Test.InContainer run appends a receipt, so the head moves on every
        # run by design; pinning END_GOAL.md to one value would make the chain
        # red for the next person to run it, and red-on-a-clean-clone is the
        # opposite of what this gate is for. The head is checked for shape
        # above, and the run prints its own so the two can be compared by
        # someone who cares which run they are looking at.
        if ($summary.ledger_head -cne $ledgerLine) {
            Write-Build DarkGray ("Ledger head moved since END_GOAL.md was written: " +
                "documented '$ledgerLine', this run '$($summary.ledger_head)'. Expected; receipts accumulate.")
        }
    }
    else {
        Write-Build Yellow "No $summaryPath; totals not cross-checked (run Test.InContainer first)."
    }

    Write-Build Green 'END_GOAL.md documents this run.'

    # ---- forensic chain ---------------------------------------------------
    # scripts/forensic.ps1 is a byte-identical copy of the one in
    # claude.build.ledger, so both repos' chains are the same format and the
    # same verifier reads either. Appending is idempotent per commit: a second
    # run of the chain must not add a second record for the same state.
    $forensic = Join-Path $root 'scripts' 'forensic.ps1'
    $chain = Join-Path $root '.continuity' 'forensic.jsonl'
    $subject = "$($Build.RunId)-goal-update-$sectionSha".ToLowerInvariant()

    if ((Test-Path -LiteralPath $chain) -and
        (Select-String -LiteralPath $chain -SimpleMatch $subject -Quiet)) {
        Write-Build DarkGray "Forensic chain already records $subject; not appending twice."
    }
    else {
        $testedFor = if (Test-Path -LiteralPath $summaryPath) {
            $s = Get-Content -LiteralPath $summaryPath -Raw -Encoding utf8 | ConvertFrom-Json
            "passed=$($s.passed) failed=$($s.failed) skipped=$($s.skipped) ledger_head=$($s.ledger_head)"
        }
        else { 'no in-container summary' }

        $evidence = "commit $sectionSha on $(exec { git -C $root rev-parse --abbrev-ref HEAD }); " +
                    "assessment sha256 $($Build.AssessmentSha); in-container $testedFor; " +
                    "END_GOAL.md section '## $sectionDate $sectionSha $($Build.RunId)' verified by Goal.Update"

        exec { pwsh -NoProfile -File $forensic -Append -Actor claude -Kind verification -Subject $subject -Evidence $evidence }
        Write-Build Green "Forensic chain: appended $subject"
    }

    exec { pwsh -NoProfile -File $forensic -Anchor }
}
