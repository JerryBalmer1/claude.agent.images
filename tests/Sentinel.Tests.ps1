#Requires -Version 7.4

<#
    The sentinel is the only thing standing between the agent and the tools, so
    these tests assert its three observable outputs exactly: what is on stdout,
    what is on stderr, and the exit code. "It denied" is not a claim worth
    testing; "stdout parsed to an object with exactly one property named
    hookSpecificOutput whose permissionDecision was deny, and the process
    exited 0" is.

    Exit codes are the part most easily got backwards, so they are asserted on
    every single case: a deny is exit 0 with a body, and exit 2 is reserved for
    the sentinel's own failures. Swap those two and the hook still looks like
    it works while the reason never reaches anyone.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

    $script:RepoRoot = Get-RepoRoot
    $script:Sentinel = Join-Path $script:RepoRoot 'hooks' 'sentinel.ps1'
    $script:LedgerModule = Get-LedgerManifestPath
    $script:GatedTools = @('Bash', 'Shell', 'Edit', 'Write')

    function script:New-Payload {
        param([string]$Tool)
        return (@{
            session_id      = 'run-01-test'
            hook_event_name = 'PreToolUse'
            tool_name       = $Tool
            tool_input      = @{ command = 'id -u' }
        } | ConvertTo-Json -Compress -Depth 5)
    }

    function script:Invoke-Sentinel {
        param(
            [AllowEmptyString()][AllowNull()][string]$Stdin,
            [string]$Mode = 'Enforce',
            [string]$LedgerPath,
            [string]$Principal = 'run-01-test',
            [string]$ConfigPath
        )
        return Invoke-LeashScript -Path $script:Sentinel -Arguments @('-Mode', $Mode) -Stdin $Stdin -Environment @{
            LEASH_LEDGER_PATH     = $LedgerPath
            LEASH_LEDGER_MODULE   = $script:LedgerModule
            LEDGER_PRINCIPAL      = $Principal
            LEASH_MODE            = $Mode
            LEASH_SENTINEL_CONFIG = $(if ($ConfigPath) { $ConfigPath } else { $null })
        }
    }

    # A sentinel config in a sandbox, with its own policy script. The body is the policy: it gets
    # -Tool and -GatedTool and must return the string 'allow' or 'deny'. Anything else it does -
    # sleep, throw, return nonsense - is what the fail-closed tests are about.
    function script:New-SentinelConfig {
        param(
            [Parameter(Mandatory)][string]$Root,
            [int]$TimeoutMs = 5000,
            [string]$FailMode = 'closed',
            [string]$PolicyBody = 'param($Tool, [string[]]$GatedTool) if ($GatedTool -contains $Tool) { ''deny'' } else { ''allow'' }',
            [string]$RawConfig
        )
        $policy = Join-Path $Root 'policy.ps1'
        [System.IO.File]::WriteAllText($policy, $PolicyBody)
        $config = Join-Path $Root 'sentinel.json'
        $text = if ($PSBoundParameters.ContainsKey('RawConfig')) { $RawConfig } else {
            [ordered]@{ schema = 'claude.agent.sentinel/1'; timeout_ms = $TimeoutMs; fail_mode = $FailMode; policy = $policy } |
                ConvertTo-Json -Compress
        }
        [System.IO.File]::WriteAllText($config, $text)
        return $config
    }

    function script:Get-LastReceipt {
        param([Parameter(Mandatory)][string]$LedgerPath)
        return (@(Get-Content -LiteralPath $LedgerPath)[-1] | ConvertFrom-Json)
    }

    # The one shape every non-allow path must have: exit 0, exactly a deny body, and a receipt
    # whose model names the reason. stdout JSON is honoured only on exit 0.
    function script:Assert-ReceiptedDeny {
        param([Parameter(Mandatory)]$Result, [Parameter(Mandatory)][string]$LedgerPath, [Parameter(Mandatory)][string]$Reason)
        $Result.ExitCode | Should -Be 0 -Because "a receipted deny is a body on exit 0; stderr: $($Result.StdErr)"
        $body = ConvertFrom-JsonSafe -Text $Result.StdOut
        @($body.PSObject.Properties.Name) | Should -Be @('hookSpecificOutput')
        $body.hookSpecificOutput.permissionDecision | Should -BeExactly 'deny'
        $body.hookSpecificOutput.permissionDecisionReason | Should -Match "reason=$([regex]::Escape($Reason))"
        $LedgerPath | Should -Exist -Because 'the deny is receipted before the sentinel exits'
        (Get-LastReceipt -LedgerPath $LedgerPath).model | Should -BeLike "*/deny:$Reason"
    }
}

Describe 'Sentinel: the vendored Ledger it depends on' -Tag 'Ledger' {
    It 'has a manifest to import' {
        $script:LedgerModule | Should -Exist
    }

    It 'EXPORTS Add-LedgerRecord, which is what the sentinel calls' {
        # Until 2026-09-23 this test asserted the opposite arrangement: that the
        # name was resolvable inside the module's session state, because the
        # manifest did not export it and the sentinel reached it that way. At the
        # vendored pin it is exported, the sentinel calls it plainly, and this
        # test is rewritten to assert the surface it actually depends on.
        #
        # ExportedCommands, not `& $module { Get-Command ... }`. The session-state
        # form passes whether or not the name is exported, so as an assertion
        # about the PUBLIC surface it has no falsifier: withdrawing the export
        # would leave it green while every hook call failed closed in production
        # with "ledger write failed".
        $module = Import-Module -Name $script:LedgerModule -PassThru -Force
        $module.ExportedCommands.Keys | Should -Contain 'Add-LedgerRecord' -Because 'the sentinel appends receipts through this export'
    }

    It 'writes a sentinel receipt through that export, at this pin' {
        # The other half, end to end: the export existing is not the same claim
        # as the hook successfully using it. This runs the real sentinel against
        # the real vendored module and hands the line it left back to the
        # module's own verifier. Nothing here reimplements the record format, so
        # a line Get-LedgerVerify accepts is a line the module wrote.
        $box = New-LeashSandbox
        try {
            $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Bash') -LedgerPath $box.LedgerPath
            $r.ExitCode | Should -Be 0 -Because $r.StdErr

            Import-Module -Name $script:LedgerModule -Force
            $verify = Get-LedgerVerify -LedgerPath $box.LedgerPath
            $verify.Ok | Should -BeTrue
            $verify.Count | Should -Be 1

            $record = (Get-Content -LiteralPath $box.LedgerPath -Raw).Trim() | ConvertFrom-Json
            $record.validator | Should -BeExactly 'sentinel'
        }
        finally { Remove-LeashSandbox -Root $box.Root }
    }
}

Describe 'Sentinel: Enforce mode' -Tag 'Ledger' {
    BeforeEach {
        $script:Box = New-LeashSandbox
    }
    AfterEach {
        Remove-LeashSandbox -Root $script:Box.Root
    }

    It 'denies <_> with exit 0 and a well-formed decision body' -ForEach @('Bash', 'Shell', 'Edit', 'Write') {
        $tool = $_
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool $tool) -LedgerPath $script:Box.LedgerPath

        # exit 0, because stdout JSON is honored ONLY on exit 0.
        $r.ExitCode | Should -Be 0 -Because 'a deny is carried by the body, not by the exit code'

        $body = ConvertFrom-JsonSafe -Text $r.StdOut
        @($body.PSObject.Properties.Name) | Should -Be @('hookSpecificOutput') -Because 'nothing else may be on stdout'
        $body.hookSpecificOutput.hookEventName | Should -BeExactly 'PreToolUse'
        $body.hookSpecificOutput.permissionDecision | Should -BeExactly 'deny'
        $body.hookSpecificOutput.permissionDecisionReason | Should -Not -BeNullOrEmpty
        $body.hookSpecificOutput.permissionDecisionReason | Should -BeLike "*$tool*"

        # The stale contract must not come back.
        $body.PSObject.Properties.Name | Should -Not -Contain 'decision'
    }

    It 'allows a non-gated tool (Read) with exactly {} and exit 0' {
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Read') -LedgerPath $script:Box.LedgerPath

        $r.ExitCode | Should -Be 0
        $r.StdOut | Should -BeExactly '{}'
        $body = ConvertFrom-JsonSafe -Text $r.StdOut
        # Count the properties, not the names: .Name on an empty property
        # collection yields $null, and @($null) has a Count of 1.
        @($body.PSObject.Properties).Count | Should -Be 0 -Because 'no opinion means no properties'
    }

    It 'writes exactly one receipt per decision, for allow and deny alike' {
        foreach ($tool in @('Bash', 'Read', 'Write')) {
            $r = Invoke-Sentinel -Stdin (New-Payload -Tool $tool) -LedgerPath $script:Box.LedgerPath
            $r.ExitCode | Should -Be 0
        }
        $script:Box.LedgerPath | Should -Exist
        @(Get-Content -LiteralPath $script:Box.LedgerPath).Count | Should -Be 3
    }

    It 'produces a chain that Get-LedgerVerify accepts' {
        foreach ($tool in @('Bash', 'Read', 'Edit')) {
            $null = Invoke-Sentinel -Stdin (New-Payload -Tool $tool) -LedgerPath $script:Box.LedgerPath
        }
        Import-Module -Name $script:LedgerModule -Force
        $verify = Get-LedgerVerify -LedgerPath $script:Box.LedgerPath
        $verify.Ok | Should -BeTrue
        $verify.Count | Should -Be 3
        $verify.LastSelf | Should -Match '^[0-9a-f]{64}$'
    }

    It 'records the decision and hashes the payload it actually saw' {
        $payload = New-Payload -Tool 'Bash'
        $null = Invoke-Sentinel -Stdin $payload -LedgerPath $script:Box.LedgerPath

        $record = (Get-Content -LiteralPath $script:Box.LedgerPath -Raw).Trim() | ConvertFrom-Json
        $record.validator | Should -BeExactly 'sentinel'
        $record.mode | Should -BeExactly 'Enforce'
        $record.model | Should -BeExactly 'run-01-test/Bash/deny'

        $expected = [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData(
                [System.Text.Encoding]::UTF8.GetBytes($payload))).ToLowerInvariant()
        $record.sha256 | Should -BeExactly $expected -Because 'the receipt must prove what the sentinel saw'
    }
}

Describe 'Sentinel: Observe mode' -Tag 'Ledger' {
    BeforeEach { $script:Box = New-LeashSandbox }
    AfterEach { Remove-LeashSandbox -Root $script:Box.Root }

    It 'returns exactly {} for a gated tool and still writes the receipt' {
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Bash') -Mode 'Observe' -LedgerPath $script:Box.LedgerPath

        $r.ExitCode | Should -Be 0
        $r.StdOut | Should -BeExactly '{}'

        $script:Box.LedgerPath | Should -Exist
        $record = (Get-Content -LiteralPath $script:Box.LedgerPath -Raw).Trim() | ConvertFrom-Json
        $record.mode | Should -BeExactly 'Observe'
        $record.model | Should -BeExactly 'run-01-test/Bash/observe'
    }

    It 'never denies, for any gated tool' -ForEach @('Bash', 'Shell', 'Edit', 'Write') {
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool $_) -Mode 'Observe' -LedgerPath $script:Box.LedgerPath
        $r.ExitCode | Should -Be 0
        $r.StdOut | Should -BeExactly '{}'
    }
}

Describe 'Sentinel: fails closed' -Tag 'Ledger' {
    BeforeEach { $script:Box = New-LeashSandbox }
    AfterEach { Remove-LeashSandbox -Root $script:Box.Root }

    # Every path that is not an explicit allow verdict is a deny, receipted before exit. Until
    # I14 PR 4 these were exit 2 with no receipt: blocked, but with nothing on the chain to say a
    # call was ever refused.
    It 'denies and receipts <Name> as reason=<Reason>' -ForEach @(
        @{ Name = 'malformed stdin'; Stdin = 'not json at all {{{'; Reason = 'malformed-payload' }
        @{ Name = 'empty stdin'; Stdin = ''; Reason = 'malformed-payload' }
        @{ Name = 'valid JSON with no tool_name'; Stdin = '{"session_id":"x"}'; Reason = 'malformed-payload' }
        @{ Name = 'a JSON array instead of an object'; Stdin = '[{"tool_name":"Bash"}]'; Reason = 'malformed-payload' }
        @{ Name = 'a bare JSON string'; Stdin = '"Bash"'; Reason = 'malformed-payload' }
    ) {
        $r = Invoke-Sentinel -Stdin $Stdin -LedgerPath $script:Box.LedgerPath
        Assert-ReceiptedDeny -Result $r -LedgerPath $script:Box.LedgerPath -Reason $Reason
        (Get-LastReceipt -LedgerPath $script:Box.LedgerPath).model | Should -BeExactly "run-01-test/-/deny:$Reason"
    }

    It 'THE FALSIFIER: a policy step stalled past the timeout is blocked, and receipted as reason=timeout' {
        # The policy sleeps 30s against a 1s budget. Blocked means a deny on stdout, and it has to
        # arrive long before the sleep ends: the host's own hook timeout fails OPEN, so a sentinel
        # that merely waits is a sentinel that allows.
        $config = New-SentinelConfig -Root $script:Box.Root -TimeoutMs 1000 -PolicyBody 'param($Tool, $GatedTool) Start-Sleep -Seconds 30; ''allow'''
        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Read') -LedgerPath $script:Box.LedgerPath -ConfigPath $config
        $clock.Stop()
        Assert-ReceiptedDeny -Result $r -LedgerPath $script:Box.LedgerPath -Reason 'timeout'
        $clock.Elapsed.TotalSeconds | Should -BeLessThan 15 -Because 'the managed-settings hook timeout is 15s and it fails open'
    }

    It 'a timeout denies in Observe mode too: Observe relaxes the policy, not the failure' {
        $config = New-SentinelConfig -Root $script:Box.Root -TimeoutMs 1000 -PolicyBody 'param($Tool, $GatedTool) Start-Sleep -Seconds 30; ''allow'''
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Read') -Mode 'Observe' -LedgerPath $script:Box.LedgerPath -ConfigPath $config
        Assert-ReceiptedDeny -Result $r -LedgerPath $script:Box.LedgerPath -Reason 'timeout'
    }

    It 'denies and receipts a policy that throws as reason=policy-crash' {
        $config = New-SentinelConfig -Root $script:Box.Root -PolicyBody 'param($Tool, $GatedTool) throw ''policy blew up'''
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Read') -LedgerPath $script:Box.LedgerPath -ConfigPath $config
        Assert-ReceiptedDeny -Result $r -LedgerPath $script:Box.LedgerPath -Reason 'policy-crash'
    }

    It 'denies and receipts a verdict that is not exactly allow or deny as reason=malformed-verdict (<Verdict>)' -ForEach @(
        @{ Verdict = 'maybe' }, @{ Verdict = 'Allow' }, @{ Verdict = '' }
    ) {
        $config = New-SentinelConfig -Root $script:Box.Root -PolicyBody "param(`$Tool, `$GatedTool) '$Verdict'"
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Read') -LedgerPath $script:Box.LedgerPath -ConfigPath $config
        Assert-ReceiptedDeny -Result $r -LedgerPath $script:Box.LedgerPath -Reason 'malformed-verdict'
    }

    It 'denies and receipts a malformed policy config as reason=malformed-policy (<Name>)' -ForEach @(
        @{ Name = 'not JSON';            Raw = 'this is not { json' }
        @{ Name = 'fail_mode open';      Raw = '{"schema":"claude.agent.sentinel/1","timeout_ms":5000,"fail_mode":"open","policy":"policy.ps1"}' }
        @{ Name = 'no timeout_ms';       Raw = '{"schema":"claude.agent.sentinel/1","fail_mode":"closed","policy":"policy.ps1"}' }
        @{ Name = 'timeout_ms too long'; Raw = '{"schema":"claude.agent.sentinel/1","timeout_ms":60000,"fail_mode":"closed","policy":"policy.ps1"}' }
        @{ Name = 'no policy script';    Raw = '{"schema":"claude.agent.sentinel/1","timeout_ms":5000,"fail_mode":"closed","policy":"no-such-policy.ps1"}' }
    ) {
        $config = New-SentinelConfig -Root $script:Box.Root -RawConfig $Raw
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Read') -LedgerPath $script:Box.LedgerPath -ConfigPath $config
        Assert-ReceiptedDeny -Result $r -LedgerPath $script:Box.LedgerPath -Reason 'malformed-policy'
    }

    It 'an explicit allow verdict is the one path that allows' {
        $config = New-SentinelConfig -Root $script:Box.Root
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Read') -LedgerPath $script:Box.LedgerPath -ConfigPath $config
        $r.ExitCode | Should -Be 0
        $r.StdOut | Should -BeExactly '{}'
        (Get-LastReceipt -LedgerPath $script:Box.LedgerPath).model | Should -BeExactly 'run-01-test/Read/allow'
    }

    It 'exits 2 when the ledger directory is not mounted' {
        $r = Invoke-Sentinel -Stdin (New-Payload -Tool 'Read') `
            -LedgerPath (Join-Path $script:Box.Root 'no-such-mount' 'ledger.jsonl')

        $r.ExitCode | Should -Be 2
        $r.StdOut | Should -BeExactly ''
        $r.StdErr | Should -Match 'ledger directory is not mounted'
    }

    It 'exits 2 when the Ledger module is missing, rather than allowing unlogged' {
        $r = Invoke-LeashScript -Path $script:Sentinel -Arguments @('-Mode', 'Enforce') `
            -Stdin (New-Payload -Tool 'Read') -Environment @{
                LEASH_LEDGER_PATH   = $script:Box.LedgerPath
                LEASH_LEDGER_MODULE = (Join-Path $script:Box.Root 'no-such-module.psd1')
                LEDGER_PRINCIPAL    = 'run-01-test'
            }

        $r.ExitCode | Should -Be 2
        $r.StdOut | Should -BeExactly ''
        $r.StdErr | Should -Match 'ledger write failed'
    }

    It 'a ledger that cannot be written still denies: exit 2, stderr, nothing on stdout' {
        # The one deny that cannot be receipted, because the receipt is what failed. Exit 2 blocks
        # the call and hands stderr to Claude; there is nowhere else to say it.
        $r = Invoke-Sentinel -Stdin 'not json' -LedgerPath (Join-Path $script:Box.Root 'no-such-mount' 'ledger.jsonl')
        $r.ExitCode | Should -Be 2
        $r.StdOut | Should -BeExactly ''
        $r.StdErr | Should -Match 'leash-sentinel: .*reason=malformed-payload'
    }
}

Describe 'One-element JSON array: one trap, met two ways' {
    # A RECURRENCE, recorded as one. Same class, same repository, twice: a PowerShell
    # pipeline unrolls a one-element JSON array into its element, so `[{...}]` arrives as a
    # perfectly good object. hooks/sentinel.ps1 met it first and defends with a raw-text
    # StartsWith('{') check at :119, before the bare ConvertFrom-Json at :125.
    # .claude/hooks/Deny-Heredoc.ps1 met it second - its first version DENIED the array while
    # its own comment claimed fail-open - and defends with -NoEnumerate at :67.
    #
    # Two defences, not one fix twice, and the intended verdicts are OPPOSITE on purpose: the
    # sentinel gates an agent that may be adversarial and fails CLOSED; Deny-Heredoc guards
    # the hands of one that is trying to comply and fails OPEN. This asserts each script's
    # own verdict, so removing either defence turns it red. Forensic chain seq 19.
    #
    # Untagged, so it runs everywhere: the sentinel refuses the array before it ever imports
    # the Ledger module, and Deny-Heredoc never loads it.
    It 'the sentinel fails closed and Deny-Heredoc fails open on [{...}], and the control is denied' {
        $inner = @{
            session_id      = 'one-element-array'
            hook_event_name = 'PreToolUse'
            tool_name       = 'Bash'
            tool_input      = @{ command = "cat <<EOF`nx`nEOF" }
        } | ConvertTo-Json -Compress -Depth 5
        $array = "[$inner]"
        $denyHeredoc = Join-Path $script:RepoRoot '.claude' 'hooks' 'Deny-Heredoc.ps1'

        $s = Invoke-LeashScript -Path $script:Sentinel -Arguments @('-Mode', 'Enforce') -Stdin $array -Environment @{
            LEASH_LEDGER_PATH   = (Join-Path ([System.IO.Path]::GetTempPath()) 'never-written' 'ledger.jsonl')
            LEASH_LEDGER_MODULE = $script:LedgerModule
            LEDGER_PRINCIPAL    = 'one-element-array'
        }
        $s.ExitCode | Should -Be 2 -Because 'the sentinel fails closed on anything that is not a JSON object'
        $s.StdOut | Should -BeExactly ''
        $s.StdErr | Should -Match 'payload is not a JSON object'

        $h = Invoke-LeashScript -Path $denyHeredoc -Stdin $array
        $h.ExitCode | Should -Be 0
        $h.StdOut | Should -BeExactly '' -Because 'Deny-Heredoc fails open on a payload that is not an object'

        # The control. Without it the line above passes against a script that allows
        # everything: the same object, unwrapped, must be denied.
        $c = Invoke-LeashScript -Path $denyHeredoc -Stdin $inner
        $c.ExitCode | Should -Be 0
        (ConvertFrom-JsonSafe -Text $c.StdOut).hookSpecificOutput.permissionDecision | Should -BeExactly 'deny'
    }
}
