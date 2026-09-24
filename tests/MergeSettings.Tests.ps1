#Requires -Version 7.4

<#
    AGENTS.md: merge commits only, and the repository enforces it.

    The settings are read LIVE, through gh api graphql, for the repository config/repo.json names.
    A merge-commit rule that only lives in prose is an honour system; GitHub will squash a pull
    request the moment someone picks that button, and nothing in the tree would notice.

    No answer is a failure, never a pass: an unauthenticated gh, a network error or a renamed
    field all fail the test with gh's own words in the message. The one exception is a machine
    with no gh at all - the images carry none - where the test skips as SkipWhen:no-gh-cli, so
    the gate reports it by reason instead of passing it. In CI the pester step gets GH_TOKEN from
    the workflow's GITHUB_TOKEN. Forensic chain seq 32.
#>

BeforeDiscovery {
    $script:NoGh = -not [bool](Get-Command -Name 'gh' -CommandType Application -ErrorAction SilentlyContinue)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $config = Get-Content -LiteralPath (Join-Path (Get-RepoRoot) 'config' 'repo.json') -Raw | ConvertFrom-Json
    $script:Owner, $script:Name = ([string]$config.repo) -split '/', 2
}

Describe 'Merge commits only, read from GitHub' {
    It 'the repository allows merge commits and nothing else' -Tag 'SkipWhen:no-gh-cli' -Skip:$script:NoGh {
        $query = 'query { repository(owner:"' + $script:Owner + '", name:"' + $script:Name + '") { mergeCommitAllowed squashMergeAllowed rebaseMergeAllowed } }'

        $PSNativeCommandUseErrorActionPreference = $false
        $raw = (& gh api graphql -f "query=$query" --jq '.data.repository' 2>&1 | Out-String).Trim()
        $code = $LASTEXITCODE

        $code | Should -Be 0 -Because "gh answered: $raw"
        $settings = ConvertFrom-JsonSafe -Text $raw
        $settings.mergeCommitAllowed | Should -BeTrue -Because 'merge commits are the only way anything lands here'
        $settings.squashMergeAllowed | Should -BeFalse -Because 'a squash has one parent and a hash that matches nothing reviewed'
        $settings.rebaseMergeAllowed | Should -BeFalse -Because 'a rebase rewrites the commits the chain cites'
    }
}
