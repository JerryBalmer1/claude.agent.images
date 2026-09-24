#Requires -Version 7.4
#
# COPIED, NOT VENDORED.
#   origin repo   : claude.agent.substrate
#   origin file   : scripts/ci/Invoke-Tests.ps1
#   origin commit : 912c1c9eb48ab0b639d257bc7b10661d7212f985
#   origin sha256 : 6c6db2077f706dca66efc6a2acd91aa3b8aa06dcd7c09d233061f7c5d14b8345
#   adapted here  : YES - adapted for this repo, diff before assuming they agree
#
# There is no submodule here and substrate does not follow this copy. If substrate's
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

# Docker-tagged tests are excluded HERE and only here. They need both images built, which is
# minutes of runner time on every push, and they are not the thing this check is for: this is
# the fast gate that says the suite is sound. The image is proved by `Invoke-Build
# Test.InContainer`, which builds it and runs the suite inside it as the non-root user, and
# whose result is recorded in END_GOAL.md and on the forensic chain for the run.
#
# That is a real gap and it is named rather than hidden: a pull request that breaks the
# Dockerfile goes green here. See docs/plans/2026-09-21-cleanup/FINDINGS.md FINDING-M13.
$excludeTag = @('Docker')

# The vendored Ledger is a PRIVATE submodule, and actions/checkout's GITHUB_TOKEN is scoped to
# this repository only - so on a runner, vendor/ is empty and every test that loads the module
# fails in a way that reads like a product defect rather than a missing checkout. Measured: the
# sentinel returning exit 2 where 0 was expected, the entrypoint calling the chain broken,
# "ledger.psd1 did not exist".
#
# Rather than pretend, this DETECTS the absence and says so. Locally and in the container the
# submodule is present and nothing is excluded; on CI the run prints exactly which tests it did
# not perform and why. Degrading visibly beats either a red build nobody can fix without a
# credential, or a green one that quietly proved less than it claims.
#
# The real fix is a PAT with read access to claude.agent.core, stored as a repository secret
# and passed to actions/checkout as `token:`. That is Jerry's to create. FINDING-M17.
$ledgerManifest = Join-Path $RepoRoot 'vendor/claude.agent.core/modules/ledger/ledger.psd1'
if (-not (Test-Path -LiteralPath $ledgerManifest)) {
    $excludeTag += 'Ledger'
    Write-Host ''
    Write-Host 'pester: WARNING -- the vendored Ledger module is NOT present.'
    Write-Host "pester:   expected  $ledgerManifest"
    Write-Host 'pester:   cause     vendor/claude.agent.core is a private submodule and the'
    Write-Host 'pester:             workflow GITHUB_TOKEN cannot clone another repository.'
    Write-Host 'pester:   effect    every Ledger-tagged test is EXCLUDED from this run.'
    Write-Host 'pester:   fix       a PAT with read access, as a repo secret, passed to'
    Write-Host 'pester:             actions/checkout as token:. See FINDING-M17.'
    Write-Host ''
}

Write-Host "pester: excluding tag(s) [$($excludeTag -join ', ')] -- see FINDING-M13, FINDING-M17"

$pc = New-PesterConfiguration
$pc.Run.Path           = $testPath
$pc.Run.PassThru       = $true
$pc.Output.Verbosity   = 'Detailed'
$pc.TestResult.Enabled = $false
$pc.Filter.ExcludeTag  = $excludeTag

$result = Invoke-Pester -Configuration $pc

Write-Host ''
Write-Host ("pester: total={0} passed={1} failed={2} skipped={3} duration={4}" -f
    $result.TotalCount, $result.PassedCount, $result.FailedCount, $result.SkippedCount, $result.Duration)

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
# not a port of it. The excluded tags are passed in because Pester reports a tag-excluded
# test as NotRun, and on a runner that is most of the suite: the Ledger-tagged tests are
# excluded above for want of a PAT (FINDING-M17) and the Docker-tagged ones by design. A
# NotRun the filter explains is tolerated; a skip with no reason on the test object is not.
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

Write-Host 'pester: PASS'
exit 0
