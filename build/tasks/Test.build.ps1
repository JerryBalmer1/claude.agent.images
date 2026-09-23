#Requires -Version 7.4

<#
.SYNOPSIS
    Test.Unit (host) and Test.InContainer (inside the built image).

.DESCRIPTION
    The two runs are not redundant. Test.Unit runs on Windows against whatever
    PowerShell the developer has; Test.InContainer runs the same suite on
    Linux, on the exact pwsh and Pester the image ships, as the non-root user
    that the leash depends on being unable to write to /opt/leash. A suite that
    only ever ran on the host has not tested the artefact being shipped.
#>

# Synopsis: Run the whole suite on this host, including the docker-tagged tests.
task Test.Unit {
    Import-Module Pester -MinimumVersion $Build.PesterVersion -ErrorAction Stop

    $outDir = $Build.OutputPath
    if (-not (Test-Path -LiteralPath $outDir)) { [void](New-Item -ItemType Directory -Path $outDir -Force) }

    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $Build.RepositoryRoot 'tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path $outDir 'host.tests.xml'
    $config.TestResult.OutputFormat = 'NUnit2.5'

    $result = Invoke-Pester -Configuration $config
    Write-Build Cyan ("Host: passed={0} failed={1} skipped={2}" -f
        $result.PassedCount, $result.FailedCount, $result.SkippedCount)

    Assert-SuiteClean -Result $result -Where 'host'
}

# Synopsis: Build the image, then run the suite inside it as the non-root user.
task Test.InContainer Build.Image, {
    $root = $Build.RepositoryRoot
    $outDir = $Build.OutputPath
    if (-not (Test-Path -LiteralPath $outDir)) { [void](New-Item -ItemType Directory -Path $outDir -Force) }

    # --entrypoint pwsh bypasses entrypoint.ps1 on purpose: the entrypoint's
    # own refusals are asserted BY the suite (Entrypoint.Tests.ps1), so making
    # the suite depend on the entrypoint arming first would be circular.
    $relativeOut = [System.IO.Path]::GetRelativePath($root, $outDir).Replace('\', '/')

    # A persistent chain for this run, mounted at /ledger. The suite's own
    # receipts go to throwaway sandboxes; this one survives, because END_GOAL.md
    # has to name a ledger head that someone can go and verify afterwards.
    $ledgerDir = Join-Path $outDir 'ledger'
    if (-not (Test-Path -LiteralPath $ledgerDir)) { [void](New-Item -ItemType Directory -Path $ledgerDir -Force) }

    # /work is a bind mount, so its files carry the HOST uid, not the container's. git refuses
    # to operate in a repository owned by another user - "detected dubious ownership", exit 128
    # - and that took down the whole BeforeAll of any suite that asks git a question, which
    # reads as 25 failures and 21 NotRun rather than as one configuration problem.
    #
    # The exception lives in build/container.gitconfig and is passed as GIT_CONFIG_GLOBAL, so it
    # is scoped to this one invocation and neither image carries it. That file documents why it
    # is a FILE and not GIT_CONFIG_COUNT/KEY/VALUE: those arrive in git's "command line" scope,
    # which was enough for `git rev-parse` but not for the `git clone /work ...` the
    # planted-twin probe does, because safe.directory is deliberately restricted in which
    # scopes it may be honoured from.
    #
    # The alternative was to tag the git-dependent tests and exclude them in here. That would
    # have been skipping tests to get green, which the run order forbids, and it would have
    # quietly dropped the secret-scan assertions from the container run.
    Write-Build Cyan "Running the suite inside $($Build.LeashTag) ..."
    exec {
        docker run --rm `
            -v "${root}:/work" `
            -v "${ledgerDir}:/ledger" `
            -w /work `
            -e LEDGER_PRINCIPAL=run-01-incontainer `
            -e GIT_CONFIG_GLOBAL=/work/build/container.gitconfig `
            --entrypoint pwsh `
            $Build.LeashTag `
            -NoProfile -File /work/build/InContainer.Test.ps1 `
            -TestPath /work/tests `
            -ResultPath "/work/$relativeOut/incontainer"
    }

    $summaryPath = Join-Path $outDir 'incontainer.json'
    if (-not (Test-Path -LiteralPath $summaryPath)) {
        throw "In-container run produced no summary at $summaryPath"
    }
    $summary = Get-Content -LiteralPath $summaryPath -Raw -Encoding utf8 | ConvertFrom-Json

    Write-Build Cyan ("Container: passed={0} failed={1} skipped={2} (pwsh {3}, Pester {4}, uid {5})" -f
        $summary.passed, $summary.failed, $summary.skipped,
        $summary.ps_version, $summary.pester_version, $summary.uid)
    Write-Build Cyan ("Ledger head: {0}" -f $summary.ledger_head)

    # The container gate already decided which skips were justified; this end reports
    # them, so the reason survives into the host log rather than only into the JSON.
    # Guarded: a summary written before justified_skips existed is still readable, and
    # StrictMode would otherwise turn an old artefact into a parse error.
    $justified = @()
    if ($summary.PSObject.Properties.Name -contains 'justified_skips') {
        $justified = @($summary.justified_skips)
    }
    foreach ($group in ($justified | Group-Object -Property reason | Sort-Object -Property Name)) {
        Write-Build Yellow ("Container: skipped — $($group.Name):")
        foreach ($t in $group.Group) { Write-Build DarkGray "    $($t.test)" }
    }

    if ($summary.uid -eq '0') { throw 'the in-container suite ran as root; it proves nothing about the leash' }
    if ($summary.failed -gt 0) { throw "$($summary.failed) test(s) failed inside the container" }
    if (@($summary.unjustified_skips).Count -gt 0) {
        throw ("no justification tag (BLOCKER-n or SkipWhen:<reason>) on: " +
            (@($summary.unjustified_skips) -join ', '))
    }
    if ($summary.passed -eq 0) { throw 'no tests ran inside the container; that is a failure, not a pass' }

    Write-Build Green 'Test.InContainer: green.'
}

function Assert-SuiteClean {
    <#
    .SYNOPSIS
        Fail on any failed test, and on any skip that does not state its reason
        on the test object. Report the skips that do.
    #>
    param(
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][string]$Where
    )

    if ($Result.FailedCount -gt 0) {
        $names = @($Result.Tests | Where-Object Result -eq 'Failed' | ForEach-Object { $_.ExpandedPath })
        # ${Where} and not $Where: a colon straight after a variable name makes
        # PowerShell read it as a scope qualifier, the way $script: does, and
        # the file will not even parse.
        throw ("${Where}: $($Result.FailedCount) test(s) failed:`n  " + ($names -join "`n  "))
    }

    # 'NotRun' is how Pester reports a test excluded by a tag filter, which is
    # not a skip and must not be counted as one. Test.Unit excludes nothing, so
    # any NotRun here really is unexplained — and neither tag form excuses one.
    #
    # The RULE for what counts as a justification lives in Build.Helpers.psm1 and
    # is shared with build/InContainer.Test.ps1. The two gates still differ on
    # NotRun, deliberately: that run carries an ExcludeTag filter and this one does
    # not. What they no longer get to differ on is what a justification IS.
    $verdicts = @(
        $Result.Tests | ForEach-Object {
            if ($_.Result -notin @('Skipped', 'Inconclusive', 'NotRun')) { return }

            $tags = @($_.Tag)
            $block = $_.Block
            while ($block) { $tags += @($block.Tag); $block = $block.Parent }

            $reason = if ($_.Result -eq 'Skipped') { Get-SkipJustification -Tag $tags } else { $null }

            [pscustomobject]@{
                Test   = $_.ExpandedPath
                Result = [string]$_.Result
                Reason = $reason
            }
        }
    )

    $unjustified = @($verdicts | Where-Object { -not $_.Reason })
    $justified   = @($verdicts | Where-Object { $_.Reason })

    # WHY, not just how many. A green log that says "skipped: 2" tells a reader
    # nothing they can act on; grouped by reason, it tells them what precondition
    # was unmet and therefore what would have to change for those tests to run.
    foreach ($group in ($justified | Group-Object -Property Reason | Sort-Object -Property Name)) {
        Write-Build Yellow ("${Where}: skipped — $($group.Name):")
        foreach ($t in $group.Group) { Write-Build DarkGray "    $($t.Test)" }
    }

    if ($unjustified.Count -gt 0) {
        throw ("${Where}: no justification tag (BLOCKER-n or SkipWhen:<reason>) on:`n  " +
            (@($unjustified | ForEach-Object { "$($_.Result.ToLowerInvariant()) — $($_.Test)" }) -join "`n  "))
    }

    if ($Result.PassedCount -eq 0) {
        throw "${Where}: no tests ran; that is a failure, not a pass"
    }
}
