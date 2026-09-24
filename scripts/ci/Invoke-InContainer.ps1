#Requires -Version 7.4
<#
.SYNOPSIS
    CI job "incontainer": build both images on the runner and run Invoke-Build Test.InContainer.

.DESCRIPTION
    The `pester` check runs the suite on the runner's own pwsh. This one runs it where the
    artefact is: inside the leash image, on the image's pwsh and Pester, as the non-root user
    the leash depends on. It is the same task a promotion measures locally as clause (b), called
    the same way - Invoke-Build is still the only entry point, and this script adds no second
    implementation of anything the task does.

    What it adds is reporting. Invoke-Build's own per-task elapsed times are printed and written
    to the job summary, because whether this job may gate pull requests was decided on the
    runner's image-build time and that number should stay visible on every run, not be quoted
    once and trusted. The in-container NotRun count is printed WITH its explanation: the only
    NotRun Test.InContainer tolerates is one excluded by tag (build/InContainer.Test.ps1
    -ExcludeTag, default Docker - there is no docker daemon inside the image), and any other
    NotRun lands in unjustified_skips and fails the task. So a NotRun this script prints after a
    green task is, by construction, a Docker-tagged test.

    InvokeBuild is pinned from config/repo.json -> tooling.invokebuild for the same reason
    Pester is pinned from tooling.pester: a runner that floats is not a control.

    output/incontainer.json is uploaded by the workflow step after this one, pass or fail.

.EXAMPLE
    pwsh -NoProfile -File scripts/ci/Invoke-InContainer.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version 3.0

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$config   = (Get-Content -LiteralPath (Join-Path $RepoRoot 'config/repo.json') -Raw | ConvertFrom-Json -Depth 20)
$pinned   = $config.tooling.invokebuild

Write-Host "incontainer: InvokeBuild pinned $pinned (config/repo.json -> tooling.invokebuild)"
$have = Get-Module -ListAvailable -Name InvokeBuild |
        Where-Object { $_.Version.ToString() -eq $pinned } |
        Select-Object -First 1
if (-not $have) {
    Write-Host "incontainer: InvokeBuild $pinned not installed, installing from PSGallery"
    Install-Module -Name InvokeBuild -RequiredVersion $pinned -Force -Scope CurrentUser -ErrorAction Stop
}
Import-Module InvokeBuild -RequiredVersion $pinned -Force -ErrorAction Stop

$manifest = Join-Path $RepoRoot 'vendor/claude.agent.core/modules/ledger/ledger.psd1'
if (-not (Test-Path -LiteralPath $manifest)) {
    # Both images COPY the vendored core. Without it the build fails on a missing path, which
    # reads like a Dockerfile defect; this says what it actually is.
    Write-Host "incontainer: FAIL -- $manifest is absent; the checkout step needs submodules: recursive"
    exit 1
}

# -Result takes a HASHTABLE, not a variable name. The name form sets the variable in the
# caller's scope by name, and on the runner that failed outright - "Cannot overwrite variable
# ib because the variable has been optimized" - after passing on the desk that wrote it.
# InvokeBuild fills $result.Value either way; this form does not depend on scope internals.
$result = @{}
$failed = $null
$clock = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Invoke-Build Test.InContainer -File (Join-Path $RepoRoot '.build.ps1') -Result $result
}
catch {
    $failed = $_
}
$clock.Stop()

$rows = [System.Collections.Generic.List[string]]::new()
$ib = if ($result.ContainsKey('Value')) { $result.Value } else { $null }
if ($ib) {
    foreach ($t in $ib.Tasks) {
        $rows.Add(('| `{0}` | {1:n1} s |' -f $t.Name, $t.Elapsed.TotalSeconds))
    }
}
$rows.Add(('| **total, this script** | **{0:n1} s** |' -f $clock.Elapsed.TotalSeconds))

Write-Host ''
Write-Host 'incontainer: elapsed by task'
foreach ($r in $rows) { Write-Host "  $r" }

$summaryPath = Join-Path $RepoRoot 'output/incontainer.json'
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('## incontainer')
$lines.Add('')
$lines.Add('| task | elapsed |')
$lines.Add('|---|---|')
foreach ($r in $rows) { $lines.Add($r) }
$lines.Add('')

if (Test-Path -LiteralPath $summaryPath) {
    $s = Get-Content -LiteralPath $summaryPath -Raw -Encoding utf8 | ConvertFrom-Json
    $notRun = [int]$s.total - [int]$s.passed - [int]$s.failed - [int]$s.skipped
    $line = 'passed={0} failed={1} skipped={2} total={3} NotRun={4} (pwsh {5}, Pester {6}, uid {7})' -f
        $s.passed, $s.failed, $s.skipped, $s.total, $notRun, $s.ps_version, $s.pester_version, $s.uid
    Write-Host "incontainer: $line"
    $lines.Add("``$line``")
    $lines.Add('')
    if ($notRun -gt 0 -and -not $failed) {
        $why = "NotRun=$notRun, every one excluded by tag Docker: no docker daemon inside the image. " +
               'Any other NotRun would be in unjustified_skips and would have failed the task.'
        Write-Host "incontainer: $why"
        $lines.Add($why)
    }
}
else {
    Write-Host "incontainer: no summary at $summaryPath"
    $lines.Add("No summary at ``output/incontainer.json``.")
}

if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $lines -Encoding utf8
}

if ($failed) {
    Write-Host ''
    Write-Host "incontainer: FAIL -- $($failed.Exception.Message)"
    exit 1
}
Write-Host 'incontainer: PASS'
exit 0
