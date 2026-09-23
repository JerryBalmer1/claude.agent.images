#Requires -Version 7.4

<#
    entrypoint.ps1 — container entrypoint. Validates, never writes policy,
    then runs the command it was handed.

    Replaces entrypoint.sh. Three reasons it is PowerShell and not bash: the
    repo's law is PowerShell 7.4+, the settings check is a JSON-structure check
    rather than a grep for a substring that could just as easily be sitting
    inside a comment, and the chain check is a real call into the Ledger module
    rather than a `# TODO`.

    This script never writes to /etc/claude-code and never edits settings. It
    reads, it verifies, it refuses. An entrypoint that repairs its own policy
    is not a gate.

    NO param() BLOCK, DELIBERATELY. An entrypoint has to hand its arguments to
    the command verbatim, and a param() block makes PowerShell try to bind them
    to this script instead:

        docker run <img> pwsh -NoProfile -c 'exit 0'
        -> "A parameter cannot be found that matches parameter name 'NoProfile'"

    That was a real failure of the first version of this file, caught by
    running it in a container rather than by reading it. Configuration
    therefore comes from the environment, which is what `docker run -e` sets
    anyway, and $args carries the command untouched.

    Configuration:
        LEASH_SETTINGS_PATH   default /etc/claude-code/managed-settings.json
        LEASH_LEDGER_DIR      default /ledger
        LEASH_LEDGER_MODULE   default /opt/leash/ledger/Ledger.psd1
        LEDGER_PRINCIPAL      required, no default
        LEASH_VERBOSE         any non-empty value turns on verbose output
        LEASH_CLAUDE_BIN      default 'claude'
        LEASH_REQUIRE_CLAUDE  any non-empty value makes an absent claude fatal (exit 16).
                              Set by both Dockerfiles: the image is the thing that can
                              promise claude is installed, so the image is the thing that
                              demands it. Unset on a host, where claude is not expected and
                              the entrypoint's own test suite runs.

    Exit codes are distinct on purpose — "it failed" is not a diagnosis, and
    tests/Entrypoint.Tests.ps1 asserts each one separately:

        0   validated (or the command's own exit code, if one ran)
       10   managed settings file missing
       11   managed settings present but not a valid leash policy
       12   LEDGER_PRINCIPAL unset
       13   ledger directory missing, unreadable or unwritable
       14   ledger chain is broken
       15   the requested command is not on PATH
       16   claude is absent while LEASH_REQUIRE_CLAUDE is set

    On identity: LEDGER_PRINCIPAL is operator-asserted. Nothing here signs it
    and nothing here can tell a true principal from a claimed one. That is a
    standing blocker, listed every run, not an oversight.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($env:LEASH_VERBOSE) { $VerbosePreference = 'Continue' }

$SettingsPath = if ($env:LEASH_SETTINGS_PATH) { $env:LEASH_SETTINGS_PATH } else { '/etc/claude-code/managed-settings.json' }
$LedgerDir    = if ($env:LEASH_LEDGER_DIR)    { $env:LEASH_LEDGER_DIR }    else { '/ledger' }
$LedgerModule = if ($env:LEASH_LEDGER_MODULE) { $env:LEASH_LEDGER_MODULE } else { '/opt/leash/ledger/Ledger.psd1' }
$GatedTool    = @('Bash', 'Shell', 'Edit', 'Write')
$ClaudeBin    = if ($env:LEASH_CLAUDE_BIN) { $env:LEASH_CLAUDE_BIN } else { 'claude' }
$RequireClaude = -not [string]::IsNullOrEmpty($env:LEASH_REQUIRE_CLAUDE)
$Command      = @($args)

# Diagnostics go to stderr so stdout belongs entirely to the command that runs
# after validation. An init that scribbles on its child's stdout is a nuisance
# to anyone piping the container.
function Write-Leash {
    param([Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine("[leash] $Message")
}

function Exit-Leash {
    param(
        [Parameter(Mandatory)][int]$Code,
        [Parameter(Mandatory)][string]$Reason
    )
    [Console]::Error.WriteLine("[leash] FATAL($Code): $Reason")
    [Console]::Error.Flush()
    exit $Code
}

function Test-SettingsProperty {
    param([Parameter(Mandatory)][AllowNull()]$Object, [Parameter(Mandatory)][string]$Name)
    return ($Object -is [pscustomobject]) -and ($Object.PSObject.Properties.Name -contains $Name)
}

# ------------------------------------------------------------------- claude
# Carried over from entrypoint.sh, which ran `claude --version` before anything else and
# refused to start if it was absent (FINDING-M8). This file replaced the .sh and kept only
# the check that the command it was ASKED to exec resolves (exit 15) - so a leash image built
# without claude in it started happily, as long as you asked it for something else.
#
# Order matches the .sh: this runs before the settings are read. An image missing the binary
# the whole leash exists to restrain is not a misconfiguration, it is the wrong image.
$claude = Get-Command -Name $ClaudeBin -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $claude) {
    if ($RequireClaude) {
        Exit-Leash -Code 16 -Reason "claude not found as '$ClaudeBin'; LEASH_REQUIRE_CLAUDE is set and an image without claude is not a leash"
    }
    Write-Leash "claude not found as '$ClaudeBin'; LEASH_REQUIRE_CLAUDE is unset, continuing"
}
else {
    # The version is the half of the .sh's behaviour that carried no exit code with it, and it
    # is the only place the PINNED claude version is witnessed at runtime - which F-22 needs if
    # the gated tool set is ever to be derived from it rather than hardcoded.
    #
    # $PSNativeCommandUseErrorActionPreference is suppressed for this one call on purpose: a
    # binary that answers --version with a non-zero exit is a diagnostic, not a reason to
    # refuse to boot. The presence check above is the gate.
    $prev = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        $reported = (& $claude.Source --version 2>&1 | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($reported)) { $reported = '(no version reported)' }
        Write-Leash "claude: $reported  [$($claude.Source)]"
    }
    finally { $PSNativeCommandUseErrorActionPreference = $prev }
}

# ------------------------------------------------------------ managed settings
if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
    Exit-Leash -Code 10 -Reason "managed settings missing: $SettingsPath"
}

$settings = $null
try {
    $settings = Get-Content -LiteralPath $SettingsPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
}
catch {
    Exit-Leash -Code 11 -Reason "managed settings are not valid JSON: $($_.Exception.Message)"
}

foreach ($flag in 'allowManagedHooksOnly', 'disableBypassPermissionsMode') {
    if (-not (Test-SettingsProperty -Object $settings -Name $flag) -or $settings.$flag -ne $true) {
        Exit-Leash -Code 11 -Reason "$flag must be present and true in $SettingsPath"
    }
}

if (-not (Test-SettingsProperty -Object $settings -Name 'hooks') -or
    -not (Test-SettingsProperty -Object $settings.hooks -Name 'PreToolUse') -or
    @($settings.hooks.PreToolUse).Count -eq 0) {
    Exit-Leash -Code 11 -Reason "no PreToolUse hook registered in $SettingsPath"
}

# claude-code#18312: a hook's permissionDecision is ignored when the tool sits
# in permissions.allow. Design around the bug by refusing to boot at all with a
# gated tool in the allow list, where it would silently defeat the sentinel.
if ((Test-SettingsProperty -Object $settings -Name 'permissions') -and
    (Test-SettingsProperty -Object $settings.permissions -Name 'allow')) {
    foreach ($rule in @($settings.permissions.allow)) {
        foreach ($tool in $GatedTool) {
            if ($rule -eq $tool -or $rule -like "$tool(*") {
                Exit-Leash -Code 11 -Reason "permissions.allow contains '$rule'; a gated tool in allow defeats the sentinel (claude-code#18312)"
            }
        }
    }
}

Write-Leash "settings ok: $SettingsPath"

# ---------------------------------------------------------------- principal
if ([string]::IsNullOrWhiteSpace($env:LEDGER_PRINCIPAL)) {
    Exit-Leash -Code 12 -Reason 'LEDGER_PRINCIPAL unset'
}
Write-Leash "principal: $($env:LEDGER_PRINCIPAL) (operator-asserted, unsigned)"

# -------------------------------------------------------------- ledger dir
if (-not (Test-Path -LiteralPath $LedgerDir -PathType Container)) {
    Exit-Leash -Code 13 -Reason "ledger directory is not mounted: $LedgerDir"
}

# The sentinel writes a receipt on every single tool call. A read-only mount
# would turn that into exit 2 on the first call and brick the agent one tool
# use in, so it is proven writable here rather than discovered later.
$probe = Join-Path $LedgerDir ".leash-write-probe-$PID"
try {
    Set-Content -LiteralPath $probe -Value 'probe' -NoNewline -ErrorAction Stop
}
catch {
    Exit-Leash -Code 13 -Reason "ledger directory is not writable: $LedgerDir ($($_.Exception.Message))"
}
finally {
    if (Test-Path -LiteralPath $probe) { [System.IO.File]::Delete($probe) }
}

# ------------------------------------------------------------- chain verify
$ledgerFile = Join-Path $LedgerDir 'ledger.jsonl'
$head = 'none'

if (-not (Test-Path -LiteralPath $ledgerFile -PathType Leaf)) {
    # A fresh mount has no receipts yet. An empty chain is a valid chain: the
    # first record links to the 64-zero genesis. Refusing here would mean the
    # leash could never be started for the first time.
    Write-Leash "no receipts yet at $ledgerFile; chain starts at genesis"
}
else {
    if (-not (Test-Path -LiteralPath $LedgerModule -PathType Leaf)) {
        Exit-Leash -Code 13 -Reason "Ledger module missing: $LedgerModule"
    }
    try {
        Import-Module -Name $LedgerModule -Force -ErrorAction Stop
    }
    catch {
        Exit-Leash -Code 13 -Reason "could not import Ledger from ${LedgerModule}: $($_.Exception.Message)"
    }

    try {
        # Get-LedgerVerify throws on the first broken link, so a returned object
        # always means Ok. One line out, because a wall of text at boot is a
        # wall of text nobody reads.
        $result = Get-LedgerVerify -LedgerPath $ledgerFile
        $head = $result.LastSelf
        Write-Leash "chain intact: $($result.Count) receipt(s), head=$head"
    }
    catch {
        Exit-Leash -Code 14 -Reason "ledger chain is broken: $($_.Exception.Message)"
    }
}

Write-Leash "armed. mode=$(if ($env:LEASH_MODE) { $env:LEASH_MODE } else { 'Enforce' }) head=$head"

# ----------------------------------------------------------------- dispatch
if ($Command.Count -eq 0) {
    Write-Leash 'no command given; validation only'
    exit 0
}

$exe = Get-Command -Name $Command[0] -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) {
    Exit-Leash -Code 15 -Reason "command not found: $($Command[0])"
}

# $Command[1..0] returns the array REVERSED rather than empty, which is a
# genuinely nasty way to pass an argument nobody asked for.
$rest = @()
if ($Command.Count -gt 1) { $rest = $Command[1..($Command.Count - 1)] }

Write-Leash "exec: $($Command -join ' ')"
& $exe.Source @rest
exit $LASTEXITCODE
