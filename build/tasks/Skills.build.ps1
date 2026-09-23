#Requires -Version 7.4

<#
.SYNOPSIS
    Skills audit: suck in skills that don't exist yet.

.DESCRIPTION
    The developer image should pull in skills referenced by plans but not yet
    built. This task lists them so agents know what to implement next.
#>

# Synopsis: Audit skills referenced by plans but not yet implemented.
task Skills.Audit {
    $plansDir = Join-Path $Build.RepositoryRoot 'plans'
    $skillsDir = Join-Path $Build.RepositoryRoot 'skills'
    $missing = @()
    if (Test-Path $plansDir) {
        Get-ChildItem $plansDir -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
            $plan = Get-Content $_.FullName -Raw | ConvertFrom-Json
            foreach ($s in @($plan.skills_to_build)) {
                $skillPath = Join-Path $skillsDir $s
                if (-not (Test-Path $skillPath)) {
                    $missing += $s
                }
            }
        }
    }
    if ($missing.Count -eq 0) {
        Write-Build Green 'No missing skills. Either none referenced or all built.'
    }
    else {
        Write-Build Yellow 'Skills referenced but not built:'
        $missing | ForEach-Object { Write-Build Yellow "  - $_" }
        Write-Build Yellow 'Implement these before the next agent run.'
    }
}
