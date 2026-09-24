#Requires -Version 7.4

<#
.SYNOPSIS
    PreToolUse sentinel. One script, one policy switch, both images.

.DESCRIPTION
    The gate Claude Code calls before every matched tool use. It speaks the
    current hook contract, which is not the one the previous version spoke:

      * A decision is carried in hookSpecificOutput.permissionDecision on
        stdout, with exit 0. The top-level "decision" key is stale and is
        ignored by current Claude Code.
      * stdout JSON is honored ONLY on exit 0. The old code emitted a deny
        body and then exited 2, so the body was discarded and the block
        depended entirely on the exit code — the reason never reached anyone.
      * exit 2 blocks the call and feeds stderr back to Claude. This script
        uses it only when a deny cannot be receipted, because the ledger is
        what failed.

    FAILS CLOSED (I14 PR 4). The only path that allows is an explicit 'allow'
    verdict from the policy step (hooks/policy.ps1). Every other path - stdin
    that is not a PreToolUse object, a config that is not the one legal shape,
    a policy that throws, returns anything but 'allow' or 'deny', or gives no
    verdict within config/sentinel.json timeout_ms - is a deny on stdout, and
    its receipt names the reason (model ends /deny:<reason>) BEFORE the script
    exits. If that receipt cannot be written, the deny goes to stderr, exit 2.

    The timeout is the sentinel's own. Claude Code's hook timeout (15 s in
    managed-settings.json) fails OPEN, so waiting it out would be an allow. The
    policy runs in its own runspace, and the sentinel stops waiting at
    timeout_ms, denies, and exits the process so a stalled policy cannot hold
    it open.

    All of the above is recorded as confirmed in
    prompts/assessment.2026-09-21.json.

    A hook decision can never widen permissions: a permissions.deny rule wins
    regardless of what this script says. The deny list in managed-settings.json
    is the wall; this script is the camera and the receipt.

.PARAMETER Mode
    Enforce - gated tools are denied.
    Observe - nothing is denied, receipts are still written.
    There is deliberately no second, no-op copy of this script for the
    developer image. Two files drift; one file with a switch does not.

.PARAMETER GatedTool
    Tools denied under Enforce. Must stay in step with the permissions.deny
    list in both managed-settings.json files; tests/Settings.Tests.ps1 asserts
    that it does.

.PARAMETER LedgerPath
    The receipt chain, on the host-mounted volume. Every decision — allow and
    deny alike — appends one Ledger record BEFORE this script returns. If the
    receipt cannot be written, the decision does not happen: stderr, exit 2.

.PARAMETER ConfigPath
    config/sentinel.json: timeout_ms, fail_mode and the policy script. It sits
    beside hooks/ in the repository and in both images (/opt/leash/config), so
    the default is resolved from this script's own folder. schemas/
    sentinel.schema.json admits exactly one fail_mode, 'closed', and this script
    refuses any other value as malformed-policy.

.NOTES
    stdout discipline: this script writes to stdout exactly once, and only a
    JSON document. Anything else there corrupts the hook response, so no
    Write-Host, no uncaptured pipeline output. Diagnostics go to the verbose,
    debug and error streams, which Claude Code does not parse as a decision.

    Receipt field mapping. The Ledger v1 record is a fixed set of eight keys
    and adding a ninth would invalidate every hash already in the file, so a
    sentinel receipt is expressed in the existing fields rather than extending
    them:

        attempt   1                          (a hook call has no retry loop)
        validator 'sentinel'
        mode      Enforce | Observe          (the policy switch)
        model     <principal>/<tool>/<decision>
        sha256    sha256 of the raw stdin payload

    sha256 over the raw payload is the part that matters: it proves what the
    sentinel actually saw, not what it later decided to say about it.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Enforce', 'Observe')]
    [string]$Mode = $(if ($env:LEASH_MODE) { $env:LEASH_MODE } else { 'Enforce' }),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$GatedTool = @('Bash', 'Shell', 'Edit', 'Write'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LedgerPath = $(if ($env:LEASH_LEDGER_PATH) { $env:LEASH_LEDGER_PATH } else { '/ledger/ledger.jsonl' }),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LedgerModule = $(if ($env:LEASH_LEDGER_MODULE) { $env:LEASH_LEDGER_MODULE } else { '/opt/leash/ledger/Ledger.psd1' }),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath = $(if ($env:LEASH_SENTINEL_CONFIG) { $env:LEASH_SENTINEL_CONFIG } else { Join-Path (Split-Path $PSScriptRoot -Parent) 'config' 'sentinel.json' })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$principal = if ($env:LEDGER_PRINCIPAL) { $env:LEDGER_PRINCIPAL } else { 'unset' }
$raw  = ''
$tool = '-'   # what a receipt names when the payload never yielded a tool
$receipt = $null

# Appends one Ledger record. Throws with a message fit for stderr if it cannot.
function Write-Receipt {
    param([Parameter(Mandatory)][string]$Decision)
    $payloadSha = [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($raw))).ToLowerInvariant()

    $ledgerDir = [System.IO.Path]::GetDirectoryName($LedgerPath)
    if ($ledgerDir -and -not (Test-Path -LiteralPath $ledgerDir)) {
        throw "ledger directory is not mounted: $ledgerDir"
    }
    try {
        Import-Module -Name $LedgerModule -Force -ErrorAction Stop

        # Add-LedgerRecord is part of the module's public surface at the vendored pin
        # (FunctionsToExport in ledger.psd1:9), so it is called plainly. Until 2026-09-23 it was
        # reached through the module's session state; called as an export, a withdrawal is loud
        # here and in tests/Sentinel.Tests.ps1 instead of passing through a private name.
        $r = Add-LedgerRecord -Path $LedgerPath -Attempt 1 -Validator 'sentinel' `
            -Mode $Mode -Model "$principal/$tool/$Decision" -Sha256 $payloadSha
    }
    catch { throw "ledger write failed: $($_.Exception.Message)" }
    Write-Verbose "[sentinel] receipt line $($r.Line) self=$($r.Self)"
    return $r
}

# The ONE deny that cannot be receipted, because the receipt is what failed. Exit 2 blocks the call
# and hands stderr to Claude. [Environment]::Exit, not exit: a stalled policy runspace must not
# be able to keep this process alive past the host's fail-open timeout.
function Exit-Unreceipted {
    param([Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine("leash-sentinel: $Message")
    [Console]::Error.Flush()
    [Environment]::Exit(2)
}

# Every path that is not an explicit allow verdict ends here: receipt first, then the deny body.
function Exit-Denied {
    param([Parameter(Mandatory)][string]$Reason, [Parameter(Mandatory)][string]$Detail)
    $r = $null
    try { $r = Write-Receipt -Decision "deny:$Reason" }
    catch { Exit-Unreceipted "deny reason=$Reason ($Detail); $($_.Exception.Message)" }

    $body = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = "Leash: $tool denied, reason=$Reason ($Detail). " +
                                       "Receipt $($r.Self) appended to $LedgerPath. Principal=$principal."
        }
    }
    [Console]::Out.Write((ConvertTo-Json -InputObject $body -Compress -Depth 5))
    [Console]::Out.Flush()
    [Environment]::Exit(0)
}

try {
    # ------------------------------------------------------------ read stdin
    try { $raw = [Console]::In.ReadToEnd() }
    catch { Exit-Denied 'malformed-payload' "could not read stdin: $($_.Exception.Message)" }
    if ($null -eq $raw) { $raw = '' }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        Exit-Denied 'malformed-payload' 'empty stdin; a PreToolUse payload is required'
    }

    # A PreToolUse payload is a JSON OBJECT. This is checked against the raw text rather than the
    # parsed result because the pipeline unrolls: '[{"tool_name":"Bash"}]' | ConvertFrom-Json
    # leaves the inner object, not the array, so a one-element array would sail through every
    # later check as a perfectly good payload.
    if (-not $raw.TrimStart().StartsWith('{')) {
        Exit-Denied 'malformed-payload' 'payload is not a JSON object'
    }

    $payload = $null
    try { $payload = $raw | ConvertFrom-Json -Depth 100 }
    catch { Exit-Denied 'malformed-payload' "stdin is not valid JSON: $($_.Exception.Message)" }

    # A payload with no tool_name is malformed, not "a tool called unknown".
    $named = $null
    if ($payload -is [pscustomobject] -and $payload.PSObject.Properties.Name -contains 'tool_name') {
        $named = [string]$payload.tool_name
    }
    if ([string]::IsNullOrWhiteSpace($named)) { Exit-Denied 'malformed-payload' 'payload has no tool_name' }
    $tool = $named
    Write-Verbose "[sentinel] mode=$Mode tool=$tool principal=$principal"

    # ------------------------------------------------------------ config
    $config = $null
    try { $config = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -Depth 10 }
    catch { Exit-Denied 'malformed-policy' "config $ConfigPath is not readable JSON: $($_.Exception.Message)" }

    $props = if ($config -is [pscustomobject]) { @($config.PSObject.Properties.Name) } else { @() }
    foreach ($key in 'schema', 'timeout_ms', 'fail_mode', 'policy') {
        if ($props -notcontains $key) { Exit-Denied 'malformed-policy' "config has no $key" }
    }
    if ([string]$config.schema -cne 'claude.agent.sentinel/1') { Exit-Denied 'malformed-policy' "config schema is '$($config.schema)'" }
    # The value is refused, not just defaulted away from: 'closed' is the only fail mode there is.
    if ([string]$config.fail_mode -cne 'closed') { Exit-Denied 'malformed-policy' "fail_mode '$($config.fail_mode)' is not 'closed'" }
    if ($config.timeout_ms -isnot [long] -and $config.timeout_ms -isnot [int]) { Exit-Denied 'malformed-policy' 'timeout_ms is not an integer' }
    $timeoutMs = [int]$config.timeout_ms
    if ($timeoutMs -lt 1 -or $timeoutMs -gt 10000) { Exit-Denied 'malformed-policy' "timeout_ms $timeoutMs is outside 1..10000" }
    $policy = [string]$config.policy
    if (-not [System.IO.Path]::IsPathRooted($policy)) { $policy = Join-Path $PSScriptRoot $policy }
    if (-not (Test-Path -LiteralPath $policy -PathType Leaf)) { Exit-Denied 'malformed-policy' "policy script not found: $policy" }

    # ------------------------------------------------------------ policy step, under the deadline
    $ps = [powershell]::Create()
    $null = $ps.AddCommand($policy).AddParameter('Tool', $tool).AddParameter('GatedTool', $GatedTool)
    $async = $ps.BeginInvoke()
    if (-not $async.AsyncWaitHandle.WaitOne($timeoutMs)) {
        $null = $ps.BeginStop($null, $null)
        Exit-Denied 'timeout' "policy gave no verdict within $timeoutMs ms"
    }
    $out = $null
    try { $out = $ps.EndInvoke($async) }
    catch { Exit-Denied 'policy-crash' $_.Exception.Message }
    if ($ps.Streams.Error.Count) { Exit-Denied 'policy-crash' ([string]$ps.Streams.Error[0]) }

    $verdicts = @($out | ForEach-Object { $_.psobject.BaseObject })
    if ($verdicts.Count -ne 1 -or $verdicts[0] -isnot [string] -or
        ($verdicts[0] -cne 'allow' -and $verdicts[0] -cne 'deny')) {
        Exit-Denied 'malformed-verdict' "policy returned $($verdicts.Count) value(s): '$($verdicts -join "', '")'"
    }
    $verdict = $verdicts[0]

    # Observe relaxes the policy's verdict, never a failure: every path above denies in both modes.
    $decision = if ($Mode -eq 'Observe') { 'observe' } else { $verdict }
    Write-Debug "[sentinel] verdict=$verdict decision=$decision"

    # ------------------------------------------------------------ receipt, then respond
    # Written BEFORE the decision is returned. A decision nobody can prove was made is a claim.
    try { $receipt = Write-Receipt -Decision $decision }
    catch { Exit-Unreceipted $_.Exception.Message }

    if ($decision -eq 'deny') {
        $body = [ordered]@{
            hookSpecificOutput = [ordered]@{
                hookEventName            = 'PreToolUse'
                permissionDecision       = 'deny'
                permissionDecisionReason = "Leash: $tool is denied by managed policy. " +
                                           "Receipt $($receipt.Self) appended to $LedgerPath. Principal=$principal."
            }
        }
        [Console]::Out.Write((ConvertTo-Json -InputObject $body -Compress -Depth 5))
    }
    else {
        # An explicit allow, or Observe. No opinion: normal permission handling applies, and the
        # receipt is already on disk either way.
        [Console]::Out.Write('{}')
    }
    [Console]::Out.Flush()
    [Environment]::Exit(0)
}
catch {
    # Anything the paths above did not foresee. Still a deny, still receipted.
    Exit-Denied 'crash' $_.Exception.Message
}
