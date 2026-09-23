#Requires -Version 7.4

<#
.SYNOPSIS
    Image-level bootstrap and floor check. Runs inside the container.

.DESCRIPTION
    Two jobs, one script, so the build-time gate and the run-time gate can never
    disagree about what "ready" means:

      -Install   (build time, as root) install the pinned Pester, then verify.
      (default)  (test time, as the non-root user) verify only.

    The floor is PowerShell 7.6. That is an *image* floor, deliberately higher
    than the 7.4 language floor that `#Requires -Version 7.4` states everywhere
    else in this repo. 7.4 is what the code needs to run; 7.6 is what this image
    promises to ship. Asserting it here means a base image that silently drifts
    backwards fails during `docker build`, not during a test run an hour later.

.PARAMETER PesterVersion
    Exact version. Not a range: "some 6.x" is not a pin.

.PARAMETER Install
    Install Pester before verifying. Build-time only; needs root.

.EXAMPLE
    pwsh -NoProfile -File build/InContainer.Bootstrap.ps1 -PesterVersion 6.1.0 -Install

.EXAMPLE
    pwsh -NoProfile -File build/InContainer.Bootstrap.ps1 -PesterVersion 6.1.0 -Verbose
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^6\.\d+\.\d+$')]
    [string]$PesterVersion = '6.1.0',

    [Parameter()]
    [switch]$Install,

    [Parameter()]
    [version]$MinimumPSVersion = '7.6'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Write-Verbose "[bootstrap] pwsh $($PSVersionTable.PSVersion) on $($PSVersionTable.Platform)"

if ($PSVersionTable.PSVersion -lt $MinimumPSVersion) {
    Write-Error "image floor is PowerShell $MinimumPSVersion, this container has $($PSVersionTable.PSVersion)"
    exit 1
}
Write-Verbose "[bootstrap] version floor ok: $($PSVersionTable.PSVersion) >= $MinimumPSVersion"

if ($Install) {
    Write-Verbose "[bootstrap] installing Pester $PesterVersion (AllUsers)"
    # AllUsers so the non-root runtime user can load Pester but cannot replace it.
    Install-PSResource -Name 'Pester' -Version $PesterVersion -Scope AllUsers `
        -TrustRepository -Reinstall -ErrorAction Stop
}

# Get-Module -ListAvailable is the honest check: it proves the module is
# discoverable by the user running this script, which is the thing the test run
# actually depends on. "Install-PSResource did not throw" does not prove that.
$found = Get-Module -ListAvailable -Name 'Pester' |
    Where-Object { $_.Version -eq [version]$PesterVersion } |
    Select-Object -First 1

if (-not $found) {
    $have = (Get-Module -ListAvailable -Name 'Pester' | ForEach-Object { $_.Version.ToString() }) -join ', '
    Write-Error "Pester $PesterVersion not discoverable as $(whoami). Present: $(if ($have) { $have } else { '<none>' })"
    exit 1
}

Write-Verbose "[bootstrap] Pester $($found.Version) at $($found.ModuleBase)"

[pscustomobject]@{
    PSVersion     = $PSVersionTable.PSVersion.ToString()
    PesterVersion = $found.Version.ToString()
    PesterBase    = $found.ModuleBase
    User          = (whoami)
    Ok            = $true
} | Format-List | Out-String | Write-Output

exit 0
