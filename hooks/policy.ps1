#Requires -Version 7.4

<#
.SYNOPSIS
    The sentinel's policy step: one verdict, 'allow' or 'deny', for one tool name.

.DESCRIPTION
    hooks/sentinel.ps1 runs this in its own runspace under the deadline in config/sentinel.json
    (timeout_ms) and accepts exactly the string 'allow' or the string 'deny' back. Anything else -
    no verdict in time, an exception, two outputs, 'Allow' - is a deny, receipted with its reason.
    The policy decides; it does not get to fail open.

    The verdict is the same rule the sentinel carried inline until I14 PR 4: a gated tool is
    denied, everything else is allowed. The gated list stays in step with permissions.deny in both
    managed-settings.json files; tests/Settings.Tests.ps1 asserts it.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Tool,
    [Parameter(Mandatory)] [string[]] $GatedTool
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($GatedTool -contains $Tool) { 'deny' } else { 'allow' }
