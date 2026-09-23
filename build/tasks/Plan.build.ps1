#Requires -Version 7.4

<#
.SYNOPSIS
    Plan contract enforcement.

.DESCRIPTION
    Two tasks used to live here and both were theatre.

    Plan.Check wrote the schema out itself if it was missing, so it could never
    report a missing schema — it just created one and passed. A check that
    repairs what it is checking is not a check.

    Test.FailFirst wrote tests/plan.failfirst.ps1 out if it was missing, ran it,
    and treated ANY failure as success. The test it wrote called
    Test-PlanStructure, which did not exist, so the task's "fail-first test
    failed as expected" was really "command not found" — and it would have kept
    reporting success after someone shipped a validator that accepted every
    plan on earth. It is deleted, and tests/Plan.Tests.ps1 replaces it with
    assertions about plans.

    Neither task creates files any more. Missing inputs are reported, not
    manufactured.
#>

# Synopsis: Validate the schema and every plan in plans/ against it.
task Plan.Check {
    $schema = Join-Path $Build.RepositoryRoot 'schemas' 'plan.schema.json'
    if (-not (Test-Path -LiteralPath $schema)) {
        throw "Plan schema missing: $schema"
    }

    $validator = Join-Path $Build.RepositoryRoot 'src' 'PlanValidator.ps1'
    if (-not (Test-Path -LiteralPath $validator)) {
        throw "Plan validator missing: $validator"
    }
    . $validator

    if (-not (Get-Command -Name 'Test-PlanStructure' -ErrorAction SilentlyContinue)) {
        throw "$validator does not define Test-PlanStructure"
    }

    $plansDir = Join-Path $Build.RepositoryRoot 'plans'
    $plans = @(Get-ChildItem -LiteralPath $plansDir -Filter '*.json' -File -ErrorAction SilentlyContinue)

    if ($plans.Count -eq 0) {
        Write-Build DarkGray 'Plan.Check: schema and validator present; no plans in plans/ to validate yet.'
        return
    }

    foreach ($p in $plans) {
        $plan = Get-Content -LiteralPath $p.FullName -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
        $null = Test-PlanStructure -Plan $plan -SchemaPath $schema
        Write-Build Green "  ok: $($p.Name)"
    }
    Write-Build Green "Plan.Check: $($plans.Count) plan(s) valid."
}
