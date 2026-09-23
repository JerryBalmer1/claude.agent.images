#Requires -Version 7.4

<#
    Replaces tests/plan.failfirst.ps1.

    That file called Test-PlanStructure when no such function existed, so both
    of its assertions passed for the wrong reason: `{ Test-PlanStructure ... }
    | Should -Throw` is satisfied just as well by "there is no such command" as
    by "the plan was rejected". It would have stayed green after someone wrote
    a validator that accepted every plan it was given.

    These tests exercise a real implementation (src/PlanValidator.ps1) and
    assert the schema itself, so a rule quietly dropped from
    schemas/plan.schema.json is caught as well as a validator that stops
    enforcing one.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    $script:SchemaPath = Join-Path $script:RepoRoot 'schemas' 'plan.schema.json'
    . (Join-Path $script:RepoRoot 'src' 'PlanValidator.ps1')

    function script:New-ValidPlan {
        return @{
            id              = 'run-01-example'
            steps           = @(@{ action = 'build' }, @{ action = 'test' })
            expected_output = 'a green default chain'
            skills_to_build = @('leash-audit')
        }
    }
}

Describe 'Plan schema' {
    BeforeAll {
        $script:Schema = Get-Content -LiteralPath $script:SchemaPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    }

    It 'exists and is parseable' {
        $script:SchemaPath | Should -Exist
        $script:Schema.title | Should -BeExactly 'AgentPlan'
    }

    It 'requires <_>' -ForEach @('id', 'steps', 'expected_output') {
        @($script:Schema.required) | Should -Contain $_
    }

    It 'declares skills_to_build as an array of strings' {
        $script:Schema.properties.PSObject.Properties.Name | Should -Contain 'skills_to_build'
        $script:Schema.properties.skills_to_build.type | Should -BeExactly 'array'
        $script:Schema.properties.skills_to_build.items.type | Should -BeExactly 'string'
    }

    It 'requires at least one step' {
        $script:Schema.properties.steps.minItems | Should -Be 1
    }
}

Describe 'Test-PlanStructure' {
    It 'is a real command, not a missing one' {
        # The exact hole the old fail-first test fell into.
        Get-Command -Name 'Test-PlanStructure' -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'accepts a complete plan' {
        Test-PlanStructure -Plan (New-ValidPlan) | Should -BeTrue
    }

    It 'accepts a plan without the optional skills_to_build' {
        $plan = New-ValidPlan
        $plan.Remove('skills_to_build')
        Test-PlanStructure -Plan $plan | Should -BeTrue
    }

    It 'accepts a plan parsed from JSON, not just a hashtable' {
        $json = (New-ValidPlan) | ConvertTo-Json -Depth 10
        Test-PlanStructure -Plan ($json | ConvertFrom-Json) | Should -BeTrue
    }

    It 'rejects a plan missing <_>' -ForEach @('id', 'steps', 'expected_output') {
        $plan = New-ValidPlan
        $plan.Remove($_)
        { Test-PlanStructure -Plan $plan } | Should -Throw "*missing required property '$_'*"
    }

    It 'rejects an empty steps array' {
        $plan = New-ValidPlan
        $plan.steps = @()
        { Test-PlanStructure -Plan $plan } | Should -Throw '*at least 1 item*'
    }

    It 'accepts a single-step plan' {
        # A one-element array arrives from JSON unwrapped; rejecting it would
        # be a bug in the validator, not in the plan.
        $plan = New-ValidPlan
        $plan.steps = @(@{ action = 'only' })
        Test-PlanStructure -Plan $plan | Should -BeTrue
    }

    It 'rejects steps given as a string' {
        $plan = New-ValidPlan
        $plan.steps = 'build then test'
        { Test-PlanStructure -Plan $plan } | Should -Throw '*must be an array*'
    }

    It 'rejects a non-string id' {
        $plan = New-ValidPlan
        $plan.id = 42
        { Test-PlanStructure -Plan $plan } | Should -Throw '*must be a string*'
    }

    It 'rejects an empty expected_output' {
        $plan = New-ValidPlan
        $plan.expected_output = '   '
        { Test-PlanStructure -Plan $plan } | Should -Throw '*must not be empty*'
    }

    It 'rejects skills_to_build containing a non-string' {
        $plan = New-ValidPlan
        $plan.skills_to_build = @('ok', 99)
        { Test-PlanStructure -Plan $plan } | Should -Throw '*only strings*'
    }

    It 'rejects a null required value as firmly as a missing one' {
        $plan = New-ValidPlan
        $plan.expected_output = $null
        { Test-PlanStructure -Plan $plan } | Should -Throw
    }
}
