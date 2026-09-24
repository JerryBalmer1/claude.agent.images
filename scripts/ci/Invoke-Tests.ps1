#Requires -Version 7.4
#
# COPIED, NOT VENDORED.
#   origin repo   : a private sibling repository (not public)
#   origin file   : scripts/ci/Invoke-Tests.ps1
#   origin commit : 912c1c9eb48ab0b639d257bc7b10661d7212f985
#   origin sha256 : 6c6db2077f706dca66efc6a2acd91aa3b8aa06dcd7c09d233061f7c5d14b8345
#   adapted here  : YES - adapted for this repo, diff before assuming they agree
#
# There is no submodule here and the origin does not follow this copy. If the origin's
# version moves, this one does not move with it. Diff the two against the origin commit
# above before assuming they still agree.
#
<#
.SYNOPSIS
    CI check "pester": runs tests/ under the exact Pester version pinned in config/repo.json.

.DESCRIPTION
    The version is PINNED, from config/repo.json -> tooling.pester, and imported with
    -RequiredVersion. A suite whose runner floats is not a control: a green that came from a
    different Pester than the one the result was recorded under proves less than it looks like.

    Windows images ship a signed Pester 3.4.0 in the system module path, whose command surface
    is incompatible with 5.x. -SkipPublisherCheck and an explicit -RequiredVersion import are
    what stop that one being picked up.

    Exits 1 if any test fails AND if the suite ran zero tests. An empty suite reports zero
    failures, which is the most flattering possible lie a test runner can tell.

.EXAMPLE
    pwsh -NoProfile -File scripts/ci/Invoke-Tests.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version 3.0

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$config   = (Get-Content -LiteralPath (Join-Path $RepoRoot 'config/repo.json') -Raw | ConvertFrom-Json -Depth 20)
$pinned   = $config.tooling.pester
$testPath = Join-Path $RepoRoot 'tests'

Write-Host "pester: pinned version $pinned (config/repo.json -> tooling.pester)"

$have = Get-Module -ListAvailable -Name Pester |
        Where-Object { $_.Version.ToString() -eq $pinned } |
        Select-Object -First 1

if (-not $have) {
    Write-Host "pester: $pinned not installed, installing from PSGallery"
    Install-Module -Name Pester -RequiredVersion $pinned -Force -SkipPublisherCheck `
                   -Scope CurrentUser -AllowClobber -ErrorAction Stop
}

Remove-Module Pester -Force -ErrorAction SilentlyContinue
Import-Module Pester -RequiredVersion $pinned -Force -ErrorAction Stop
Write-Host "pester: imported $((Get-Module Pester).Version)"

# NO TAG IS EXCLUDED. Until 2026-09-24 the Docker tag was, and the 21 Docker-tagged tests were
# reported NotRun here and tolerated because the filter explained them: they ran on a host with
# docker and in CI nowhere, so a pull request that broke a Dockerfile went green. Ubuntu runners
# ship docker, and the Docker-tagged Describe builds both images itself, so this check now runs
# them (I12 PR 4, forensic seq 36). tests/CiCoverage.Tests.ps1 holds this at @(), and the gate
# below fails the check on any NotRun at all. A test that cannot run here takes a SkipWhen tag.
$excludeTag = @()

# The vendored Ledger MUST be present. Without it every Ledger-tagged test fails in a way that
# reads like a product defect rather than a missing checkout - measured: the sentinel returning
# exit 2 where 0 was expected, the entrypoint calling the chain broken, "ledger.psd1 did not
# exist" - so its absence is named here and fails the check before any test runs.
#
# Until 2026-09-23 absence EXCLUDED the Ledger tag instead, with a warning, because the
# submodule was believed private and fetching it needed a PAT nobody had created (FINDING-M17,
# recorded in the sibling this repository was born from, not in this tree). core is public:
# ci.yml checks it out with `submodules: recursive` and no token, and PR #9's pester job ran all
# 43 Ledger-tagged tests that way. With the credential reason gone, the exclusion had become an
# unguarded green - drop the checkout line and 43 tests go quietly NotRun while this passes.
# M17 is retired on the forensic chain at seq 21.
$ledgerManifest = Join-Path $RepoRoot 'vendor/claude.agent.core/modules/ledger/ledger.psd1'
if (-not (Test-Path -LiteralPath $ledgerManifest)) {
    Write-Host ''
    Write-Host 'pester: FAIL -- the vendored Ledger module is NOT present.'
    Write-Host "pester:   expected  $ledgerManifest"
    Write-Host 'pester:   fix       the actions/checkout step needs submodules: recursive.'
    Write-Host 'pester:             core is public; no token is required.'
    exit 1
}

Write-Host 'pester: excluding no tag - every test runs, the Docker-tagged ones included'

$pc = New-PesterConfiguration
$pc.Run.Path           = $testPath
$pc.Run.PassThru       = $true
$pc.Output.Verbosity   = 'Detailed'
$pc.TestResult.Enabled = $false
$pc.Filter.ExcludeTag  = $excludeTag

$result = Invoke-Pester -Configuration $pc

Write-Host ''
Write-Host ("pester: total={0} passed={1} failed={2} skipped={3} notrun={4} duration={5}" -f
    $result.TotalCount, $result.PassedCount, $result.FailedCount, $result.SkippedCount, $result.NotRunCount, $result.Duration)

if ($result.TotalCount -eq 0) {
    Write-Host 'pester: FAIL -- the suite ran zero tests; an empty suite is not a green'
    exit 1
}

# THE FLOOR, NOT THE CEILING: this makes CI red on an unjustified skip, exactly as
# Invoke-Build Test.Unit is; it does NOT make CI prove what Test.InContainer proves.
#
# Until this call existed, the only conditions above were "zero tests" and "a failed test",
# so a skipped test with no justification tag went GREEN here while the same tree went red
# under Invoke-Build. A required check that passes what the build fails is not a gate.
#
# Assert-SuiteClean is the SAME function Test.Unit calls, from build/Build.Helpers.psm1 -
# not a port of it. No tag is excluded, so every NotRun it sees is unexplained; the explicit
# gate after it says so by name.
$helpers = Join-Path $RepoRoot 'build/Build.Helpers.psm1'
Import-Module $helpers -Force -ErrorAction Stop

try {
    Assert-SuiteClean -Result $result -Where 'pester' -ExcludeTag $excludeTag
}
catch {
    # The message already names the check and every offending test, so it is printed as
    # thrown rather than wrapped - "pester: FAIL -- pester: ..." reads like a bug.
    Write-Host ''
    Write-Host $_.Exception.Message
    Write-Host 'pester: FAIL'
    exit 1
}
# NOTHING SILENT. A NotRun test is one this check neither ran nor skipped with a reason; with no
# tag excluded there is no legitimate source of one, so any is a failure by name.
if ($result.NotRunCount -gt 0) {
    $names = @($result.Tests | Where-Object Result -eq 'NotRun' | ForEach-Object { $_.ExpandedPath })
    Write-Host ''
    Write-Host ("pester: FAIL -- {0} test(s) NotRun, and nothing is excluded:" -f $result.NotRunCount)
    $names | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host 'pester: PASS'
exit 0
