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
            [string]$Principal = 'run-01-test'
        )
        return Invoke-LeashScript -Path $script:Sentinel -Arguments @('-Mode', $Mode) -Stdin $Stdin -Environment @{
            LEASH_LEDGER_PATH   = $LedgerPath
            LEASH_LEDGER_MODULE = $script:LedgerModule
            LEDGER_PRINCIPAL    = $Principal
            LEASH_MODE          = $Mode
        }
    }
}

Describe 'Sentinel: the vendored Ledger it depends on' -Tag 'Ledger' {
    It 'has a manifest to import' -Skip {
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

    It 'exits 2 with empty stdout on <Name>' -ForEach @(
        @{ Name = 'malformed stdin'; Stdin = 'not json at all {{{' }
        @{ Name = 'empty stdin'; Stdin = '' }
        @{ Name = 'valid JSON with no tool_name'; Stdin = '{"session_id":"x"}' }
        @{ Name = 'a JSON array instead of an object'; Stdin = '[{"tool_name":"Bash"}]' }
        @{ Name = 'a bare JSON string'; Stdin = '"Bash"' }
    ) {
        $r = Invoke-Sentinel -Stdin $Stdin -LedgerPath $script:Box.LedgerPath

        $r.ExitCode | Should -Be 2 -Because 'exit 2 blocks the call and feeds stderr back to Claude'
        $r.StdOut | Should -BeExactly '' -Because 'a body on a failure path would be discarded anyway, and hides the error'
        $r.StdErr | Should -Match 'leash-sentinel:'
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

    It 'writes no receipt when it fails closed' {
        $null = Invoke-Sentinel -Stdin 'not json' -LedgerPath $script:Box.LedgerPath
        $script:Box.LedgerPath | Should -Not -Exist -Because 'a payload it could not parse is not a decision it made'
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
