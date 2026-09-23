#Requires -Version 7.4

<#
    Managed settings are the wall. The sentinel is the camera.

    A hook decision can never widen permissions, and it is ignored entirely
    when the tool sits in permissions.allow (claude-code#18312). So the single
    most valuable assertion in this file is the negative one: no gated tool
    appears in permissions.allow in either image. That is the configuration
    that would leave the sentinel running, logging, and completely powerless.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    $script:GatedTools = @('Bash', 'Shell', 'Edit', 'Write')

    $script:LeashSettingsPath = Join-Path $script:RepoRoot 'managed-settings.json'
    $script:DevSettingsPath = Join-Path $script:RepoRoot 'images' 'developer' 'managed-settings.json'

    function script:Get-Settings {
        param([string]$Path)
        return Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    }

    function script:Test-MatcherCoversTool {
        param([string]$Matcher, [string]$Tool)
        if ([string]::IsNullOrWhiteSpace($Matcher)) { return $false }
        if ($Matcher -eq '*') { return $true }
        # Claude Code matchers are regex-ish; a tool is covered if the pattern
        # matches its name.
        try { return [bool]($Tool -match $Matcher) } catch { return $false }
    }
}

Describe 'Managed settings: <Name>' -ForEach @(
    @{ Name = 'leash'; Key = 'Leash'; Mode = 'Enforce' }
    @{ Name = 'developer'; Key = 'Dev'; Mode = 'Observe' }
) {
    BeforeAll {
        $script:Path = if ($Key -eq 'Leash') { $script:LeashSettingsPath } else { $script:DevSettingsPath }
        $script:S = Get-Settings -Path $script:Path
    }

    It 'exists and parses' {
        $script:Path | Should -Exist
        $script:S | Should -Not -BeNullOrEmpty
    }

    It 'sets allowManagedHooksOnly true' {
        $script:S.allowManagedHooksOnly | Should -BeTrue
    }

    It 'sets disableBypassPermissionsMode true' {
        $script:S.disableBypassPermissionsMode | Should -BeTrue
    }

    It 'registers a PreToolUse hook' {
        @($script:S.hooks.PreToolUse).Count | Should -BeGreaterThan 0
    }

    It 'has a PreToolUse matcher covering <_>' -ForEach @('Bash', 'Shell', 'Edit', 'Write') {
        $tool = $_
        $covered = @($script:S.hooks.PreToolUse) |
            Where-Object { Test-MatcherCoversTool -Matcher $_.matcher -Tool $tool }
        @($covered).Count | Should -BeGreaterThan 0 -Because "$tool must reach the sentinel"
    }

    It 'points the hook at the one sentinel script' {
        $commands = @($script:S.hooks.PreToolUse) | ForEach-Object { @($_.hooks) | ForEach-Object { $_.command } }
        @($commands).Count | Should -BeGreaterThan 0
        foreach ($c in $commands) {
            $c | Should -BeLike '*/opt/leash/hooks/sentinel.ps1*'
            $c | Should -BeLike '*-NoProfile*'
        }
    }

    It "runs the sentinel in <Mode> mode" {
        $commands = @($script:S.hooks.PreToolUse) | ForEach-Object { @($_.hooks) | ForEach-Object { $_.command } }
        foreach ($c in $commands) { $c | Should -BeLike "*-Mode $Mode*" }
    }

    It 'never lists a gated tool in permissions.allow (claude-code#18312)' {
        $allow = @($script:S.permissions.allow)
        foreach ($rule in $allow) {
            foreach ($tool in $script:GatedTools) {
                $bad = ($rule -eq $tool) -or ($rule -like "$tool(*")
                $bad | Should -BeFalse -Because "allow rule '$rule' would make the sentinel's decision on $tool be ignored"
            }
        }
    }
}

Describe 'Managed settings: the leash denies the gated tools' {
    BeforeAll { $script:S = Get-Settings -Path $script:LeashSettingsPath }

    It 'denies <_>' -ForEach @('Bash', 'Shell(*)', 'Edit(*)', 'Write(*)') {
        @($script:S.permissions.deny) | Should -Contain $_
    }

    It 'has a non-empty deny list' {
        @($script:S.permissions.deny).Count | Should -BeGreaterOrEqual 4
    }
}

Describe 'Managed settings: enforce and observe differ only in the mode' {
    It 'the developer image observes rather than denies' {
        $dev = Get-Settings -Path $script:DevSettingsPath
        # An Observe image with the gated tools denied would make the whole
        # mode pointless: permissions.deny wins over any hook decision.
        @($dev.permissions.deny).Count | Should -Be 0 -Because 'deny beats the hook, so Observe must not deny'
    }
}

Describe 'Dockerfiles lock the policy files down' -ForEach @(
    @{ Name = 'leash'; File = 'Dockerfile' }
    @{ Name = 'developer'; File = 'images/developer/Dockerfile' }
) {
    BeforeAll {
        $script:Text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $File) -Raw
    }

    It 'makes the settings root-owned and 0555' {
        $script:Text | Should -Match 'chown -R root:root /etc/claude-code'
        $script:Text | Should -Match 'chmod 0555 /etc/claude-code/managed-settings\.json'
    }

    It 'makes the settings DIRECTORY read-only too' {
        # A writable directory lets the file be replaced by unlink-and-create,
        # which a read-only file alone does not prevent.
        $script:Text | Should -Match 'chmod 0555 /etc/claude-code\b'
    }

    It 'makes /opt/leash root-owned and 0555' {
        $script:Text | Should -Match 'chown -R root:root /opt/leash'
        $script:Text | Should -Match 'chmod -R 0555 /opt/leash'
    }

    It 'runs as a non-root user' {
        $script:Text | Should -Match 'USER claude'
    }
}
