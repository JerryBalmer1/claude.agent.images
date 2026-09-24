#Requires -Version 7.4

<#
    config/sentinel.json holds the sentinel's timeout and fail mode (I14 PR 4). There is one legal
    fail mode, 'closed', and these tests forbid 'open' as a VALUE, not just as the default: the
    schema enumerates exactly one, the shipped file uses it, and tests/Sentinel.Tests.ps1 runs the
    sentinel against a config that says "open" and requires a receipted deny, reason=malformed-policy.

    The timeout is bounded by the host. Claude Code's PreToolUse hook timeout is 15s in both
    managed-settings files and a hook that exceeds it fails OPEN, so the sentinel's own deadline
    has to leave room inside those 15s for pwsh to start, the Ledger to load and a receipt to be
    written. The bound is written down here as a number, not trusted to a comment.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    $script:ConfigPath = Join-Path $script:RepoRoot 'config' 'sentinel.json'
    $script:SchemaPath = Join-Path $script:RepoRoot 'schemas' 'sentinel.schema.json'
    # Measured headroom the sentinel needs outside its policy deadline: pwsh start, Ledger import,
    # one receipt. 5s is the margin; the ceiling below is the host's 15s minus it.
    $script:HeadroomMs = 5000
}

Describe 'config/sentinel.json' {
    It 'exists and parses' {
        $script:ConfigPath | Should -Exist
        { Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'fails closed' {
        (Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json).fail_mode | Should -BeExactly 'closed'
    }

    It 'names a policy script that exists beside the sentinel' {
        $policy = (Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json).policy
        $policy | Should -Not -BeNullOrEmpty
        [System.IO.Path]::IsPathRooted($policy) | Should -BeFalse -Because 'it resolves against hooks/, in the repo and in the image alike'
        Join-Path $script:RepoRoot 'hooks' $policy | Should -Exist
    }

    It 'has a timeout that fits inside every managed-settings hook timeout, with 5000 ms of headroom' {
        $timeout = [int](Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json).timeout_ms
        $timeout | Should -BeGreaterThan 0
        foreach ($settings in @('managed-settings.json', 'images/developer/managed-settings.json')) {
            $s = Get-Content -LiteralPath (Join-Path $script:RepoRoot $settings) -Raw | ConvertFrom-Json
            foreach ($h in @($s.hooks.PreToolUse | ForEach-Object { $_.hooks })) {
                ($timeout + $script:HeadroomMs) | Should -BeLessOrEqual ([int]$h.timeout * 1000) -Because "$settings hook timeout is $($h.timeout)s and fails open"
            }
        }
    }
}

Describe 'schemas/sentinel.schema.json' {
    It 'allows exactly one fail_mode, and it is closed' {
        $schema = Get-Content -LiteralPath $script:SchemaPath -Raw | ConvertFrom-Json
        @($schema.properties.fail_mode.enum) | Should -Be @('closed')
        @($schema.required) | Should -Contain 'fail_mode'
        @($schema.required) | Should -Contain 'timeout_ms'
    }

    It 'bounds timeout_ms to what the host leaves room for' {
        $schema = Get-Content -LiteralPath $script:SchemaPath -Raw | ConvertFrom-Json
        [int]$schema.properties.timeout_ms.maximum | Should -Be (15000 - $script:HeadroomMs)
    }

    It 'the shipped config validates against it' {
        Test-Json -Json (Get-Content -LiteralPath $script:ConfigPath -Raw) -SchemaFile $script:SchemaPath | Should -BeTrue
    }

    It 'a config saying fail_mode "open" does not validate' {
        $open = (Get-Content -LiteralPath $script:ConfigPath -Raw) -replace '"closed"', '"open"'
        Test-Json -Json $open -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue | Should -BeFalse
    }
}

Describe 'both images ship the config where the sentinel looks for it' {
    It '<_> copies config/sentinel.json to /opt/leash/config/sentinel.json' -ForEach @('Dockerfile', 'images/developer/Dockerfile') {
        (Get-Content -LiteralPath (Join-Path $script:RepoRoot $_) -Raw) |
            Should -Match '(?m)^COPY config/sentinel\.json /opt/leash/config/sentinel\.json\s*$'
    }
}
