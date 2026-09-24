#Requires -Version 7.4
<#
.SYNOPSIS
    Runs the repo's Pester suite. Read-only: it never commits, pushes or tags.

.DESCRIPTION
    Pinned to ONE Pester, the one config/repo.json -> tooling.pester names: the version
    scripts/ci/Invoke-Tests.ps1 and Test.Unit run and the only one the images ship. Three
    majors are installed on this machine (3.4.0, 5.7.1, 6.1.0) and an unpinned
    `Import-Module Pester` takes the highest, which changes the configuration API underneath
    the suite without warning. Until 2026-09-24 this pinned the 5.x range instead, which the
    images do not carry at all (forensic seq 26).

    The root is the folder this script lives in, never the caller's current directory, and no
    folder name is asserted. Until 2026-09-24 this threw unless the caller's git toplevel ended in
    this repository's name, which refused every clone under another name and the container,
    where the repository is mounted at /work. tests/RunnerFolder.Tests.ps1 holds it to that.

    A later plan extends this runner. Keep the contract: -Path narrows the run,
    -Evidence tees the transcript to a file, exit code is 0 green / 1 red.
#>
[CmdletBinding()]
param(
    # Test files or directories to run. Defaults to every *.Tests.ps1 beside this script.
    [string[]] $Path,

    # Tee the full transcript to this file as well as the screen.
    [string] $Evidence
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

if (-not $Path) { $Path = Join-Path $repoRoot 'tests' }

# The pinned version from config, not a range. See the note above.
$pinned = (Get-Content -LiteralPath (Join-Path $repoRoot 'config' 'repo.json') -Raw |
    ConvertFrom-Json -Depth 20).tooling.pester
Import-Module Pester -RequiredVersion $pinned -Force
Write-Verbose ("Pester {0}" -f (Get-Module Pester).Version)

if ($Evidence) {
    $evidenceDir = Split-Path -Parent $Evidence
    if ($evidenceDir -and -not (Test-Path -LiteralPath $evidenceDir)) {
        $null = New-Item -ItemType Directory -Path $evidenceDir -Force
    }
    Start-Transcript -LiteralPath $Evidence -Force | Out-Null
}

try {
    $config = New-PesterConfiguration
    $config.Run.Path = $Path
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.Should.ErrorAction = 'Continue'   # report every failure in a run, not just the first

    $result = Invoke-Pester -Configuration $config

    Write-Host ''
    Write-Host ("SUITE: {0} passed, {1} failed, {2} skipped" -f
        $result.PassedCount, $result.FailedCount, $result.SkippedCount)
}
finally {
    if ($Evidence) { Stop-Transcript | Out-Null }
}

if ($result.FailedCount -gt 0) { exit 1 }
exit 0
