#Requires -Version 7.4
<#
.SYNOPSIS
    From nothing to both images green: a fresh clone, one command, on a machine with only git,
    docker and pwsh.

.DESCRIPTION
    Clones the repository into a NEW folder that is not the checkout this script was started
    from, initialises the core submodule, and refuses to go further unless the submodule is checked
    out at the pin config/vendor.json names, which must also be the gitlink the tree records. Then,
    inside the clone and through the build's only entry point, it runs

        Invoke-Build Test.InContainer [-NoCache]

    which builds both images and runs the suite inside the leash image as the non-root user.
    Exit 0 only if every step did.

    Nothing here names a path on any machine. The clone goes under the system temp folder unless
    -Path says otherwise, the repository URL comes from config/repo.json, and the only thing it
    installs is InvokeBuild, at the version config/repo.json -> tooling.invokebuild pins, for the
    current user and only when that version is absent.

    Replacing the submodule with a fetch of a core release is NOT done here and is not attempted.
    It is recorded as a finding in the pull request that added this script.

.PARAMETER Ref
    Branch, tag or commit to check out in the clone. Defaults to develop.

.PARAMETER Path
    Folder to clone into. It must not exist yet. Defaults to a new folder under the temp path.

.PARAMETER Repository
    Clone URL. Defaults to https://github.com/<config/repo.json -> repo>.git.

.PARAMETER NoCache
    Build the images cold: no reused image, no layer cache, base re-pulled.

.EXAMPLE
    pwsh -NoProfile -File scripts/Bootstrap-Clean.ps1 -NoCache
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateNotNullOrEmpty()] [string] $Ref = 'develop',
    [string] $Path,
    [string] $Repository,
    [switch] $NoCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Write-Step([string]$Text) { Write-Host "bootstrap: $Text" }
function Stop-Bootstrap([string]$Why) {
    [Console]::Error.WriteLine("bootstrap: FAIL -- $Why")
    exit 1
}

$here   = Split-Path $PSScriptRoot -Parent
$config = Get-Content -LiteralPath (Join-Path $here 'config' 'repo.json') -Raw | ConvertFrom-Json
if (-not $Repository) { $Repository = "https://github.com/$($config.repo).git" }
if (-not $Path) { $Path = Join-Path ([System.IO.Path]::GetTempPath()) ("leash-bootstrap-{0}" -f [guid]::NewGuid().ToString('N').Substring(0, 12)) }
$Path = [System.IO.Path]::GetFullPath($Path)

# ---------------------------------------------------------------- a clone that is not this checkout
if (Test-Path -LiteralPath $Path) { Stop-Bootstrap "$Path already exists; a bootstrap clones into a new folder" }
$herePrefix = [System.IO.Path]::GetFullPath($here).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
if (($Path + [System.IO.Path]::DirectorySeparatorChar).StartsWith($herePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    Stop-Bootstrap "$Path is inside the checkout this script runs from; it must be somewhere else"
}

# ---------------------------------------------------------------- the machine
foreach ($tool in 'git', 'docker') {
    if (-not (Get-Command -Name $tool -CommandType Application -ErrorAction SilentlyContinue)) { Stop-Bootstrap "$tool is not on PATH" }
}
Write-Step "pwsh $($PSVersionTable.PSVersion), $((& git --version | Out-String).Trim()), docker $((& docker version --format '{{.Server.Version}}' | Out-String).Trim())"

Write-Step "cloning $Repository into $Path"
& git clone --quiet $Repository $Path
& git -C $Path -c advice.detachedHead=false checkout --quiet $Ref
$head = (& git -C $Path rev-parse HEAD | Out-String).Trim()
Write-Step "checked out $Ref at $head"

# ---------------------------------------------------------------- the submodule, at the pin
& git -C $Path submodule update --init --recursive --quiet
$vendor = Get-Content -LiteralPath (Join-Path $Path 'config' 'vendor.json') -Raw | ConvertFrom-Json
foreach ($sm in @($vendor.submodules)) {
    $gitlink = ((& git -C $Path ls-tree HEAD -- $sm.path | Out-String).Trim() -split '\s+')[2]
    $actual  = (& git -C (Join-Path $Path $sm.path) rev-parse HEAD | Out-String).Trim()
    Write-Step "$($sm.path): config pin $($sm.pin), gitlink $gitlink, checked out $actual"
    if ($gitlink -cne $sm.pin) { Stop-Bootstrap "$($sm.path): the tree's gitlink $gitlink is not the config pin $($sm.pin)" }
    if ($actual -cne $sm.pin)  { Stop-Bootstrap "$($sm.path): checked out $actual, not the config pin $($sm.pin)" }
}

# ---------------------------------------------------------------- the one build tool, pinned
$ibVersion = [string](Get-Content -LiteralPath (Join-Path $Path 'config' 'repo.json') -Raw | ConvertFrom-Json).tooling.invokebuild
if (-not (Get-Module -ListAvailable -Name InvokeBuild | Where-Object { $_.Version.ToString() -eq $ibVersion })) {
    Write-Step "installing InvokeBuild $ibVersion for the current user"
    Install-Module -Name InvokeBuild -RequiredVersion $ibVersion -Scope CurrentUser -Force -ErrorAction Stop
}
Import-Module -Name InvokeBuild -RequiredVersion $ibVersion -Force

# ---------------------------------------------------------------- both images, and the suite inside one
Write-Step "Invoke-Build Test.InContainer$(if ($NoCache) { ' -NoCache' }) in $Path"
$clock = [System.Diagnostics.Stopwatch]::StartNew()
Push-Location -LiteralPath $Path
try {
    $buildArgs = @{ Task = 'Test.InContainer'; File = (Join-Path $Path '.build.ps1') }
    if ($NoCache) { $buildArgs['NoCache'] = $true }
    Invoke-Build @buildArgs
}
catch { Stop-Bootstrap "Invoke-Build Test.InContainer failed: $($_.Exception.Message)" }
finally { Pop-Location }
$clock.Stop()

$summary = Get-Content -LiteralPath (Join-Path $Path 'output' 'incontainer.json') -Raw | ConvertFrom-Json
if ($summary.failed -ne 0 -or $summary.passed -eq 0) { Stop-Bootstrap "in-container suite: passed=$($summary.passed) failed=$($summary.failed)" }

foreach ($tag in 'claude.pwsh.image.leash:run-01', 'claude.pwsh.image.developer:run-01') {
    Write-Step "image $tag $((& docker image inspect --format '{{.Id}}' $tag | Out-String).Trim())"
}
Write-Step "in-container passed=$($summary.passed) failed=$($summary.failed) skipped=$($summary.skipped)"
Write-Step "PASS -- $head, both images built, suite green inside, $([int]$clock.Elapsed.TotalSeconds)s"
exit 0
