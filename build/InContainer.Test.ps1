#Requires -Version 7.4

<#
.SYNOPSIS
    Run the Pester suite inside the container, as the non-root user.

.DESCRIPTION
    Invoked by the Test.InContainer task. The repository is bind-mounted at
    /work; this script runs from inside the image so the suite is exercised
    against the PowerShell, the Pester and the filesystem the image actually
    ships, rather than against whatever the host happens to have.

    It refuses to run as root. A suite that passes as root has not tested the
    thing the leash depends on, which is that the agent user cannot write to
    /opt/leash.

    Docker-tagged tests are excluded: there is no docker daemon in here, and
    those assertions are about the image, so they belong on the host that can
    build it.

.PARAMETER BlockerTagPattern
    A skipped test is tolerated only if it carries a tag naming the blocker
    that justifies it. "No test may be marked Skip or Pending without a
    BLOCKER-n reference" is otherwise an honour-system rule, and the honour
    system is what produced a green suite with a fake validator in it.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestPath = '/work/tests',

    [Parameter()]
    [string]$ResultPath = '/work/output/incontainer',

    [Parameter()]
    [string[]]$ExcludeTag = @('Docker'),

    [Parameter()]
    [string]$BlockerTagPattern = '^BLOCKER-\d+$',

    # BLOCKER-6. The runtime floor is declared ONCE, in InContainer.Bootstrap.ps1, and read
    # from there. It used to be a second independent '7.6' literal here, which meant the two
    # could disagree and nothing would notice - a floor that exists in two places is not a
    # floor, it is a coincidence.
    #
    # Read from the AST rather than by grepping for a version-shaped string: the parser returns
    # the parameter's actual default, so this cannot drift into matching a comment or a
    # different parameter that happens to look similar.
    #
    # NOT unified with the Dockerfile `ARG PWSH_URL` pins. Those are pins, not floors, and a
    # Docker build-arg cannot read a PowerShell default. Unifying them needs the config file
    # that this pass is explicitly forbidden to create.
    [Parameter()]
    [version]$MinimumPSVersion = (& {
        $bootstrap = Join-Path $PSScriptRoot 'InContainer.Bootstrap.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($bootstrap, [ref]$null, [ref]$null)
        $p = $ast.ParamBlock.Parameters |
             Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPSVersion' } |
             Select-Object -First 1
        if (-not $p) { throw "InContainer.Bootstrap.ps1 declares no MinimumPSVersion to read the floor from" }
        $p.DefaultValue.Value
    }),

    [Parameter()]
    [string]$LedgerDir = '/ledger',

    [Parameter()]
    [string]$ImageSentinel = '/opt/leash/hooks/sentinel.ps1',

    [Parameter()]
    [string]$ImageLedgerModule = '/opt/leash/ledger/Ledger.psd1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$whoami = & whoami
$uid = & id -u
Write-Output "[in-container] user=$whoami uid=$uid pwsh=$($PSVersionTable.PSVersion)"

if ($uid -eq '0') {
    Write-Error '[in-container] refusing to run the suite as root: it would not test the thing the leash depends on'
    exit 1
}

if ($PSVersionTable.PSVersion -lt $MinimumPSVersion) {
    Write-Error "[in-container] image floor is $MinimumPSVersion, got $($PSVersionTable.PSVersion)"
    exit 1
}

Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
Write-Output "[in-container] Pester $((Get-Module Pester).Version)"

$resultDir = Split-Path -Parent $ResultPath
if ($resultDir -and -not (Test-Path -LiteralPath $resultDir)) {
    [void](New-Item -ItemType Directory -Path $resultDir -Force)
}

$config = New-PesterConfiguration
$config.Run.Path = $TestPath
$config.Run.PassThru = $true
$config.Filter.ExcludeTag = $ExcludeTag
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "$ResultPath.xml"
$config.TestResult.OutputFormat = 'NUnit2.5'

$result = Invoke-Pester -Configuration $config

# Skips are judged individually. A suite may skip a test that cannot pass yet,
# but only where the reason is written down as a tag.
#
# 'NotRun' and 'Skipped' are NOT the same thing and must not be treated as one.
# Pester reports a test excluded by -ExcludeTag as NotRun, so lumping them
# together makes the 21 Docker-tagged tests — deliberately not run in here,
# because there is no docker daemon — look like 21 undocumented skips. Only a
# NotRun that is NOT explained by the exclude filter is a problem.
function Get-InheritedTag {
    param($Test)
    $tags = @($Test.Tag)
    $block = $Test.Block
    while ($block) {
        $tags += @($block.Tag)
        $block = $block.Parent
    }
    return @($tags | Where-Object { $_ })
}

$unjustified = @(
    $result.Tests | Where-Object {
        $tags = Get-InheritedTag -Test $_
        $hasBlocker = [bool](@($tags) | Where-Object { $_ -match $BlockerTagPattern })
        $excludedByTag = [bool](@($tags) | Where-Object { $ExcludeTag -contains $_ })

        ($_.Result -eq 'Skipped' -and -not $hasBlocker) -or
        ($_.Result -eq 'Inconclusive') -or
        ($_.Result -eq 'NotRun' -and -not $excludedByTag -and -not $hasBlocker)
    }
)

# ---------------------------------------------------------------- ledger head
#
# The suite runs against the repository copy of the sentinel, mounted at /work.
# This does not: it drives the copy baked into the IMAGE, /opt/leash/hooks, with
# the IMAGE's vendored Ledger, writing to the host-mounted chain. So the run
# leaves a receipt produced by the artefact being shipped, and END_GOAL.md's
# "Ledger head hash" is a hash of something that actually happened rather than a
# number copied out of a test fixture.
$ledgerHead = 'unavailable'
if (Test-Path -LiteralPath $LedgerDir -PathType Container) {
    try {
        $payload = '{"session_id":"run-01","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{}}'
        $payload | & (Get-Process -Id $PID).Path -NoProfile -File $ImageSentinel -Mode Enforce | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "image sentinel exited $LASTEXITCODE" }

        Import-Module -Name $ImageLedgerModule -Force -ErrorAction Stop
        $verify = Get-LedgerVerify -LedgerPath (Join-Path $LedgerDir 'ledger.jsonl')
        $ledgerHead = $verify.LastSelf
        Write-Output "[in-container] ledger: $($verify.Count) receipt(s), head=$ledgerHead"
    }
    catch {
        $ledgerHead = "unavailable: $($_.Exception.Message)"
        Write-Warning "[in-container] ledger head unavailable: $($_.Exception.Message)"
    }
}

$summary = [ordered]@{
    ledger_head        = $ledgerHead
    passed             = $result.PassedCount
    failed             = $result.FailedCount
    skipped            = $result.SkippedCount
    total              = $result.TotalCount
    duration_s         = [math]::Round($result.Duration.TotalSeconds, 2)
    ps_version         = $PSVersionTable.PSVersion.ToString()
    pester_version     = (Get-Module Pester).Version.ToString()
    uid                = $uid
    unjustified_skips  = @($unjustified | ForEach-Object { $_.ExpandedPath })
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$ResultPath.json" -Encoding utf8

Write-Output ("[in-container] passed={0} failed={1} skipped={2}" -f
    $result.PassedCount, $result.FailedCount, $result.SkippedCount)

if ($result.FailedCount -gt 0) {
    Write-Error "[in-container] $($result.FailedCount) test(s) failed"
    exit 1
}

if ($unjustified.Count -gt 0) {
    foreach ($t in $unjustified) { Write-Error "[in-container] skipped without a BLOCKER-n tag: $($t.ExpandedPath)" }
    exit 1
}

if ($result.PassedCount -eq 0) {
    # An empty run is not a pass. A bad -TestPath would otherwise report
    # perfect success having asserted nothing at all.
    Write-Error '[in-container] no tests ran; that is a failure, not a pass'
    exit 1
}

Write-Output '[in-container] green'
exit 0
