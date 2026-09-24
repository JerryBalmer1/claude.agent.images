#Requires -Version 7.4

<#
    AGENTS.md: the commit at main's tip has a completed ci run.

    Automerge merges with the workflow's GITHUB_TOKEN, and GitHub starts no workflow for a push made
    with that token - so an automerged promotion landed on main with no ci run at all (6b8943a,
    measured: zero). workflow_dispatch is exempt from that rule, so after a merge into main,
    automerge now dispatches ci.yml on main. Forensic chain seq 34.

    Three parts, because the live claim alone could not have been red before the fix and green
    after it inside one pull request:

      1. The dispatch decision, driven with gh shadowed by a function: a merge into main
         dispatches ci.yml on main, a merge into develop dispatches nothing.
      2. The checker, on two fixed commits: 6b8943a has no ci run (the red case, kept for good),
         74c1db2 has one.
      3. The live claim on main's tip. It skips as SkipWhen:main-predates-ci-dispatch while main's
         own Invoke-AutoMerge.ps1 lacks the dispatch - automerge's workflow_run runs main's copy,
         so the promotion that carries the dispatch is merged without it - and as
         SkipWhen:no-gh-cli inside the images.
#>

BeforeDiscovery {
    $script:NoGh = -not [bool](Get-Command -Name 'gh' -CommandType Application -ErrorAction SilentlyContinue)
    $script:MainPredates = $true
    if (-not $script:NoGh) {
        $root = Split-Path -Parent $PSScriptRoot
        $repo = (Get-Content -LiteralPath (Join-Path $root 'config' 'repo.json') -Raw | ConvertFrom-Json).repo
        $PSNativeCommandUseErrorActionPreference = $false
        $b64 = (& gh api "repos/$repo/contents/scripts/Invoke-AutoMerge.ps1?ref=main" --jq '.content' 2>$null | Out-String) -replace '\s', ''
        if ($LASTEXITCODE -eq 0 -and $b64) {
            $text = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))
            $script:MainPredates = -not $text.Contains('Invoke-CiDispatchOnMain')
        }
    }
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:Root = Get-RepoRoot
    $script:Config = Get-Content -LiteralPath (Join-Path $script:Root 'config' 'repo.json') -Raw | ConvertFrom-Json
    $script:Repo = [string]$script:Config.repo

    # Completed ci.yml runs for one commit, from the Actions API. Throws on no answer.
    function script:Get-CompletedCiRun {
        param([Parameter(Mandatory)][string]$Sha)
        $PSNativeCommandUseErrorActionPreference = $false
        $raw = (& gh api "repos/$script:Repo/actions/workflows/ci.yml/runs?head_sha=$Sha&status=completed&per_page=20" 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw "gh api answered exit $LASTEXITCODE for $Sha - $raw" }
        return @((ConvertFrom-JsonSafe -Text $raw).workflow_runs)
    }
}

Describe 'Automerge dispatches ci on main after a promotion' {
    BeforeAll {
        . (Join-Path $script:Root 'scripts' 'AutoMerge.Lib.ps1')
        $script:Calls = [System.Collections.Generic.List[string]]::new()
        function script:gh { $script:Calls.Add(($args -join ' ')); $global:LASTEXITCODE = 0 }
    }
    AfterAll { Remove-Item -Path Function:\gh -ErrorAction SilentlyContinue }

    It 'dispatches ci.yml on main for a merge into main' {
        $script:Calls.Clear()
        $r = Invoke-CiDispatchOnMain -Repo 'o/n' -BaseRef 'main' -Config $script:Config
        $r.Dispatched | Should -BeTrue
        @($script:Calls) | Should -Be @('workflow run ci.yml --repo o/n --ref main')
    }

    It 'dispatches nothing for a merge into develop' {
        $script:Calls.Clear()
        $r = Invoke-CiDispatchOnMain -Repo 'o/n' -BaseRef 'develop' -Config $script:Config
        $r.Dispatched | Should -BeFalse
        $script:Calls.Count | Should -Be 0
    }

    It 'Invoke-AutoMerge.ps1 calls it after the merge' {
        $text = Get-Content -LiteralPath (Join-Path $script:Root 'scripts' 'Invoke-AutoMerge.ps1') -Raw
        $text.IndexOf('Invoke-CiDispatchOnMain') | Should -BeGreaterThan $text.IndexOf('& gh @mergeArgs')
    }

    It 'ci.yml accepts workflow_dispatch and automerge may dispatch it' {
        (Get-Content -LiteralPath (Join-Path $script:Root '.github' 'workflows' 'ci.yml') -Raw) | Should -Match '(?m)^\s{2}workflow_dispatch:'
        (Get-Content -LiteralPath (Join-Path $script:Root '.github' 'workflows' 'automerge.yml') -Raw) | Should -Match '(?m)^\s{2}actions:\s*write'
    }
}

Describe 'The ci-run checker, on fixed commits' {
    It 'measures 6b8943a - automerged, no dispatch - as having no ci run' -Tag 'SkipWhen:no-gh-cli' -Skip:$script:NoGh {
        @(Get-CompletedCiRun -Sha '6b8943a8d1b74388ca30873704026d584ee95bc1').Count | Should -Be 0
    }

    It 'finds the completed ci run 74c1db2 has' -Tag 'SkipWhen:no-gh-cli' -Skip:$script:NoGh {
        @(Get-CompletedCiRun -Sha '74c1db23dd435cbe512e61d5dddd743c74c1b882').Count | Should -BeGreaterThan 0
    }
}

Describe 'The commit at main''s tip has a completed ci run' {
    BeforeDiscovery {
        # One reason, chosen here, so the gate reports the true one: no gh at all, or a main whose
        # own automerge cannot have dispatched yet. Otherwise the claim is live.
        $script:LiveTag = if ($script:NoGh) { 'SkipWhen:no-gh-cli' }
                          elseif ($script:MainPredates) { 'SkipWhen:main-predates-ci-dispatch' }
                          else { 'LiveGitHub' }
        $script:LiveSkip = $script:NoGh -or $script:MainPredates
    }

    It 'main''s tip has a completed, successful ci run' -Tag $script:LiveTag -Skip:$script:LiveSkip {
        $PSNativeCommandUseErrorActionPreference = $false
        $sha = (& gh api "repos/$script:Repo/commits/main" --jq '.sha' 2>&1 | Out-String).Trim()
        $LASTEXITCODE | Should -Be 0 -Because "gh answered: $sha"

        $runs = @(Get-CompletedCiRun -Sha $sha)
        $runs.Count | Should -BeGreaterThan 0 -Because "main's tip $sha must have a completed ci run"
        @($runs | Where-Object conclusion -eq 'success').Count | Should -BeGreaterThan 0 -Because "a ci run on $sha exists but none succeeded"
    }
}
