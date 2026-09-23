#Requires -Version 7.4
<#
.SYNOPSIS
    The snake. Reads a plan, checks its skills exist, dry-runs it, and drafts the next one.

.DESCRIPTION
    Plans are law. This script is the thing that enforces that mechanically, so the
    law is not just prose in AGENTS.md that an agent can talk itself out of.

    It is dry-run-first. The default is a dry run; real execution requires BOTH
    -Execute and -Go, where -Go stands for the human having said GO. The snake
    never merges, never pushes, and never creates a tag without -Go.

.PARAMETER Plan
    Path to the plan file, repo-relative. Defaults to docs/plans/ACTIVE.md.
    When the default is used and the file is absent, a dry run reports "no active
    plan" and exits 0 - that is what keeps CI green on a branch that has not
    opened a plan yet. When -Plan is passed explicitly, a missing file is exit 1.

.PARAMETER All
    Lint every plan under docs/plans/ that opts in with a "Status:" line. Archived
    and legacy plans have no Status line and are skipped: an archived plan is an
    immutable record of what was authorised, not a document to re-lint against a
    later template.

.EXAMPLE
    pwsh -NoProfile -File scripts/snake.ps1 -DryRun

.EXAMPLE
    pwsh -NoProfile -File scripts/snake.ps1 -Execute -Go

.EXAMPLE
    pwsh -NoProfile -File scripts/snake.ps1 -Archive -Go -Pr 2 -Ci green
#>
[CmdletBinding()]
param(
    [string] $Plan = 'docs/plans/ACTIVE.md',
    [switch] $DryRun,
    [switch] $Execute,
    [switch] $Go,
    [switch] $Archive,
    [switch] $NextPlan,
    [switch] $All,
    [string] $Pr = '',
    [ValidateSet('green', 'red', 'skipped')]
    [string] $Ci = 'skipped'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Section headers every plan must carry. Keys are normalised: lower-cased and
# truncated at the first "(" so "## Verify (local, no commit)" matches "verify".
$script:RequiredSections = @(
    'goal'
    'context'
    'business outcome'
    'skills referenced'
    'allow-list'
    'do-not-touch'
    'steps'
    'verify'
    'progress'
    'report block'
    'jerry action required'
)

function Get-RepoRoot {
    [CmdletBinding()]
    param()
    $root = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw 'snake: not inside a git work tree.'
    }
    Write-Debug "repo root: $root"
    return $root.Trim()
}

function ConvertTo-SectionKey {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Heading)
    return ($Heading -replace '\(.*$', '').Trim().ToLowerInvariant()
}

function Test-SectionEmpty {
    <#  A section counts as empty when nothing survives stripping blank lines,
        HTML comments, bare list bullets, and unfilled <placeholders>. That is
        what stops a plan being archived with the template text still in it. #>
    [CmdletBinding()]
    param([string[]] $Lines)
    foreach ($line in $Lines) {
        $t = $line.Trim()
        if ($t -eq '') { continue }
        if ($t.StartsWith('<!--')) { continue }
        if ($t -match '^-+$') { continue }
        if ($t -match '^-\s*$') { continue }
        if ($t -match '^<[^>]+>$') { continue }
        if ($t -match '^-\s*<[^>]+>$') { continue }
        return $false
    }
    return $true
}

function Get-FencedBlock {
    <#  Returns each fenced code block in the given lines as a string[]. #>
    [CmdletBinding()]
    param([string[]] $Lines)
    $blocks = [System.Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $Lines) {
        if ($line -match '^\s*[`]{3}') {
            if ($null -eq $current) {
                $current = [System.Collections.Generic.List[string]]::new()
            }
            else {
                if ($current.Count -gt 0) { $blocks.Add($current.ToArray()) }
                $current = $null
            }
            continue
        }
        if ($null -ne $current) { $current.Add($line) }
    }
    if ($null -ne $current -and $current.Count -gt 0) {
        Write-Warning 'snake: unterminated code fence in plan; taking it to end of section.'
        $blocks.Add($current.ToArray())
    }
    return , $blocks.ToArray()
}

function Read-Plan {
    <#  Parses a plan into sections and metadata. Missing required section = throw. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "snake: plan not found: $Path"
    }
    Write-Verbose "reading plan: $Path"
    $lines = Get-Content -LiteralPath $Path

    $sections = [ordered]@{}
    $meta = [ordered]@{ Title = ''; Date = ''; Branch = ''; PR = ''; Status = '' }
    $key = $null
    $buffer = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        if ($line -match '^#\s+Plan:\s*(.+)$') { $meta.Title = $Matches[1].Trim(); continue }
        if ($null -eq $key -and $line -match '^(Date|Branch|PR|Status):\s*(.*)$') {
            $meta[$Matches[1]] = $Matches[2].Trim()
            continue
        }
        if ($line -match '^##\s+(.+)$') {
            if ($null -ne $key) { $sections[$key] = $buffer.ToArray() }
            $key = ConvertTo-SectionKey -Heading $Matches[1]
            $buffer = [System.Collections.Generic.List[string]]::new()
            continue
        }
        if ($null -ne $key) { $buffer.Add($line) }
    }
    if ($null -ne $key) { $sections[$key] = $buffer.ToArray() }

    $missing = $script:RequiredSections | Where-Object { -not $sections.Contains($_) }
    if ($missing) {
        throw ("snake: plan is missing required section(s): {0}. See docs/skills/plan-authoring.md" -f ($missing -join ', '))
    }
    Write-Debug ("sections found: {0}" -f ($sections.Keys -join ', '))

    $slug = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    if ($slug -eq 'ACTIVE' -and $meta.Branch -match 'feature/(.+)$') { $slug = $Matches[1] }
    $slug = $slug -replace '^\d{4}-\d{2}-\d{2}-', ''

    return [pscustomobject]@{
        Path     = $Path
        Slug     = $slug
        Meta     = $meta
        Sections = $sections
    }
}

function Test-Skills {
    <#  Every skill a plan names must exist. Missing skill = STOP, not a warning. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $PlanObject,
        [Parameter(Mandatory)][string] $RepoRoot
    )
    $named = foreach ($line in $PlanObject.Sections['skills referenced']) {
        if ($line -match '^\s*-\s*\[?([A-Za-z0-9._/-]+)\]?') { $Matches[1] }
    }
    $named = $named |
        ForEach-Object { ($_ -replace '^docs/skills/', '') -replace '\.md$', '' } |
        Where-Object { $_ -and $_ -notin @('none', 'n/a') } |
        Select-Object -Unique

    if (-not $named) {
        Write-Warning 'snake: plan names no skills. That is allowed, but it is usually a smell.'
        return @()
    }

    $missing = foreach ($skill in $named) {
        $file = Join-Path $RepoRoot "docs/skills/$skill.md"
        if (Test-Path -LiteralPath $file) {
            Write-Verbose "skill OK: $skill"
        }
        else {
            $skill
        }
    }
    if ($missing) {
        throw ("snake: plan names skill(s) that do not exist: {0}. Write docs/skills/<name>.md first, or remove the reference." -f ($missing -join ', '))
    }
    return $named
}

function Test-Outcome {
    <#  business-outcomes: a plan cannot close on an empty outcome. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $PlanObject)
    $lines = $PlanObject.Sections['business outcome']
    if (Test-SectionEmpty -Lines $lines) { return $null }
    return ($lines | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim()
}

function Invoke-Block {
    <#  Runs one fenced block as a real script file. A file, not -Command, so the
        block's own quoting survives contact with the shell. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]] $Lines,
        [Parameter(Mandatory)][string] $Label
    )
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("snake-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    $prelude = @(
        '$ErrorActionPreference = ''Stop'''
        '$PSNativeCommandUseErrorActionPreference = $true'
    )
    Set-Content -LiteralPath $tmp -Value ($prelude + $Lines) -Encoding utf8
    try {
        Write-Verbose "running $Label"
        pwsh -NoProfile -File $tmp
        Write-Verbose "$Label exit 0"
        return $true
    }
    catch {
        Write-Error "snake: $Label failed: $($_.Exception.Message)" -ErrorAction Continue
        return $false
    }
    finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Steps {
    <#  Numbered steps. A step with a fenced block is executable; a prose step is
        manual and is reported as such, so nobody mistakes it for automated. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $PlanObject,
        [switch] $Real
    )
    $lines = $PlanObject.Sections['steps']
    $steps = [System.Collections.Generic.List[object]]::new()
    $title = $null
    $buffer = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        if ($line -match '^\s*\d+\.\s+(.+)$') {
            if ($null -ne $title) { $steps.Add([pscustomobject]@{ Title = $title; Body = $buffer.ToArray() }) }
            $title = $Matches[1].Trim()
            $buffer = [System.Collections.Generic.List[string]]::new()
            continue
        }
        if ($null -ne $title) { $buffer.Add($line) }
    }
    if ($null -ne $title) { $steps.Add([pscustomobject]@{ Title = $title; Body = $buffer.ToArray() }) }

    if ($steps.Count -eq 0) { throw 'snake: plan has no numbered steps.' }

    $manual = 0
    $failed = 0
    $n = 0
    foreach ($step in $steps) {
        $n++
        $blocks = Get-FencedBlock -Lines $step.Body
        $short = if ($step.Title.Length -gt 76) { $step.Title.Substring(0, 73) + '...' } else { $step.Title }
        if ($blocks.Count -eq 0) {
            $manual++
            Write-Host ("  [{0,2}] MANUAL    {1}" -f $n, $short)
            continue
        }
        foreach ($block in $blocks) {
            if ($Real) {
                Write-Host ("  [{0,2}] RUN       {1}" -f $n, $short)
                if (-not (Invoke-Block -Lines $block -Label "step $n")) { $failed++ }
            }
            else {
                Write-Host ("  [{0,2}] WOULD RUN {1}" -f $n, $short)
                foreach ($cmd in $block) {
                    if ($cmd.Trim()) { Write-Host "            $ $cmd" }
                }
            }
        }
    }
    return [pscustomobject]@{ Total = $steps.Count; Manual = $manual; Failed = $failed }
}

function Test-Verify {
    <#  The plan's verify block. All must pass. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $PlanObject,
        [switch] $Real
    )
    $blocks = Get-FencedBlock -Lines $PlanObject.Sections['verify']
    if ($blocks.Count -eq 0) {
        Write-Warning 'snake: verify section has no fenced commands. Nothing proves the work.'
        return [pscustomobject]@{ Blocks = 0; Failed = 0; Ran = $false }
    }
    $failed = 0
    $i = 0
    foreach ($block in $blocks) {
        $i++
        if ($Real) {
            if (-not (Invoke-Block -Lines $block -Label "verify block $i")) { $failed++ }
        }
        else {
            Write-Host "  verify block ${i}:"
            foreach ($cmd in $block) {
                if ($cmd.Trim()) { Write-Host "            $ $cmd" }
            }
        }
    }
    return [pscustomobject]@{ Blocks = $blocks.Count; Failed = $failed; Ran = [bool]$Real }
}

function Get-RefSha {
    <#  A ref that does not exist is normal, not an error: a CI checkout often has
        no origin/main. $PSNativeCommandUseErrorActionPreference turns git's exit 128
        into a terminating error, so it has to be caught here rather than tested for. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RepoRoot,
        [Parameter(Mandatory)][string] $Ref
    )
    try {
        $sha = git -C $RepoRoot rev-parse --short $Ref 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) { return 'unknown' }
        return $sha.Trim()
    }
    catch {
        Write-Debug "ref not resolvable: $Ref"
        return 'unknown'
    }
}

function Write-Report {
    <#  The standard report block, to stdout and to docs/plans/<slug>-report.md. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $PlanObject,
        [Parameter(Mandatory)][string] $RepoRoot,
        [Parameter(Mandatory)][string] $Mode,
        [string[]] $Skills = @(),
        [string] $Outcome = ''
    )
    $head = Get-RefSha -RepoRoot $RepoRoot -Ref 'HEAD'
    $branch = (git -C $RepoRoot rev-parse --abbrev-ref HEAD).Trim()
    $mainSha = Get-RefSha -RepoRoot $RepoRoot -Ref 'origin/main'
    $devSha = Get-RefSha -RepoRoot $RepoRoot -Ref 'origin/develop'
    $dirty = @(git -C $RepoRoot status --porcelain)
    $tags = @(git -C $RepoRoot tag -l)

    $treeState = if ($dirty.Count -gt 0) { "dirty ($($dirty.Count) paths)" } else { 'clean' }
    $skillList = if ($Skills -and $Skills.Count -gt 0) { $Skills -join ', ' } else { 'none' }
    $outcomeText = if ($Outcome) { $Outcome } else { 'EMPTY - plan cannot be closed' }
    $tagList = if ($tags.Count -gt 0) { $tags -join ', ' } else { 'none' }

    $report = @(
        "HEAD local:              $head $branch"
        "origin/main:             $mainSha"
        "origin/develop:          $devSha"
        "Working tree:            $treeState"
        "Plan:                    $($PlanObject.Path) [$($PlanObject.Meta.Status)]"
        "Mode:                    $Mode"
        "Skills referenced:       $skillList"
        "Business outcome:        $outcomeText"
        "Annotated tags:          $tagList"
        "Merged:                  no"
        "Pushed:                  no"
        "Committed:               no"
    )
    Write-Host ''
    $report | ForEach-Object { Write-Host $_ }

    $reportPath = Join-Path $RepoRoot ("docs/plans/{0}-report.md" -f $PlanObject.Slug)
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $fence = [string][char]0x60 * 3
    $entry = @('', "## $stamp - $Mode", '', ($fence + 'text')) + $report + @($fence, '')
    Add-Content -LiteralPath $reportPath -Value $entry
    Write-Verbose "report appended: $reportPath"
}

function Invoke-Archive {
    <#  Move the plan to archive/, clear ACTIVE.md, create the annotated tag. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $PlanObject,
        [Parameter(Mandatory)][string] $RepoRoot,
        [Parameter(Mandatory)][string] $Outcome,
        [string] $PrNumber,
        [string] $CiState
    )
    $date = if ($PlanObject.Meta.Date -match '^\d{4}-\d{2}-\d{2}$') {
        $PlanObject.Meta.Date
    }
    else {
        (Get-Date).ToString('yyyy-MM-dd')
    }
    $archiveDir = Join-Path $RepoRoot 'docs/plans/archive'
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    $dest = Join-Path $archiveDir ("{0}-{1}.md" -f $date, $PlanObject.Slug)

    Write-Verbose "archiving to $dest"
    Copy-Item -LiteralPath $PlanObject.Path -Destination $dest -Force

    $active = Join-Path $RepoRoot 'docs/plans/ACTIVE.md'
    if (Test-Path -LiteralPath $active) {
        Remove-Item -LiteralPath $active -Force
        Write-Verbose 'ACTIVE.md cleared'
    }

    $tag = "plan/{0}-{1}" -f $PlanObject.Slug, $date
    $message = @(
        "plan: docs/plans/archive/$date-$($PlanObject.Slug).md"
        "branch: $($PlanObject.Meta.Branch)"
        "pr: #$PrNumber"
        "ci: $CiState"
        "outcome: $Outcome"
    ) -join [Environment]::NewLine

    git -C $RepoRoot tag -a $tag -m $message
    Write-Host "snake: annotated tag created: $tag (not pushed)"
}

function New-NextPlan {
    <#  Draft the next plan from the backlog. Never commits - the human reviews. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RepoRoot,
        [switch] $Force
    )
    $backlog = Join-Path $RepoRoot 'docs/plans/BACKLOG.md'
    if (-not (Test-Path -LiteralPath $backlog)) {
        Write-Verbose 'creating docs/plans/BACKLOG.md'
        Set-Content -LiteralPath $backlog -Encoding utf8 -Value @(
            '# Backlog'
            ''
            'One line per candidate plan, newest intent at the top. The snake takes the'
            'first unchecked item when drafting the next plan.'
            ''
            '- [ ] (nothing queued)'
        )
    }
    $item = Get-Content -LiteralPath $backlog |
        Where-Object { $_ -match '^\s*-\s*\[\s*\]\s*(.+)$' } |
        Select-Object -First 1
    if (-not $item) {
        Write-Warning 'snake: backlog has no unchecked items. Nothing to draft.'
        return
    }
    $title = ($item -replace '^\s*-\s*\[\s*\]\s*', '').Trim()

    $active = Join-Path $RepoRoot 'docs/plans/ACTIVE.md'
    if ((Test-Path -LiteralPath $active) -and -not $Force) {
        throw 'snake: ACTIVE.md already exists. Archive it first, or pass -Go to overwrite.'
    }

    $template = Join-Path $RepoRoot 'docs/plans/_template.md'
    if (-not (Test-Path -LiteralPath $template)) { throw 'snake: docs/plans/_template.md is missing.' }

    $slug = ($title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    $date = (Get-Date).ToString('yyyy-MM-dd')
    $draft = (Get-Content -LiteralPath $template -Raw).
        Replace('<title>', $title).
        Replace('YYYY-MM-DD', $date).
        Replace('feature/<slug>', "feature/$slug")

    Set-Content -LiteralPath $active -Value $draft -Encoding utf8
    Write-Host "snake: drafted docs/plans/ACTIVE.md from backlog item: $title"
    Write-Host 'snake: NOT committed. Fill Goal, Context, Business outcome and Allow-list, then review.'
}

function Invoke-OnePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $RepoRoot,
        [switch] $Real
    )
    Write-Host ''
    Write-Host "=== snake: $Path ==="
    $planObject = Read-Plan -Path $Path
    $shownTitle = if ($planObject.Meta.Title) { $planObject.Meta.Title } else { $planObject.Slug }
    Write-Host ("plan:     {0}" -f $shownTitle)
    Write-Host ("branch:   {0}    status: {1}" -f $planObject.Meta.Branch, $planObject.Meta.Status)

    $skills = @(Test-Skills -PlanObject $planObject -RepoRoot $RepoRoot)
    $shownSkills = if ($skills.Count -gt 0) { $skills -join ', ' } else { 'none' }
    Write-Host ("skills:   {0}" -f $shownSkills)

    $outcome = Test-Outcome -PlanObject $planObject
    if ($outcome) {
        Write-Host "outcome:  $outcome"
    }
    else {
        Write-Warning 'snake: ## Business outcome is empty. This plan cannot be archived until it is filled.'
    }

    Write-Host 'steps:'
    $stepResult = Invoke-Steps -PlanObject $planObject -Real:$Real
    Write-Host ("          {0} step(s), {1} manual, {2} failed" -f $stepResult.Total, $stepResult.Manual, $stepResult.Failed)

    Write-Host 'verify:'
    $verifyResult = Test-Verify -PlanObject $planObject -Real:$Real

    return [pscustomobject]@{
        Plan    = $planObject
        Skills  = $skills
        Outcome = $outcome
        Steps   = $stepResult
        Verify  = $verifyResult
        Failed  = ($stepResult.Failed + $verifyResult.Failed)
    }
}

# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

if ($DryRun -and $Execute) {
    throw 'snake: -DryRun and -Execute are mutually exclusive.'
}
if ($Execute -and -not $Go) {
    throw 'snake: -Execute requires -Go. The snake does not run a plan for real without a human GO.'
}
if ($Archive -and -not $Go) {
    throw 'snake: -Archive requires -Go. Tags and archives are human-gated.'
}

$repoRoot = Get-RepoRoot
Push-Location $repoRoot
try {
    $real = [bool]$Execute
    $mode = if ($real) { 'execute' } else { 'dry-run' }
    Write-Verbose "snake mode: $mode"

    if ($NextPlan) {
        New-NextPlan -RepoRoot $repoRoot -Force:$Go
        exit 0
    }

    if ($All) {
        $candidates = Get-ChildItem -Path (Join-Path $repoRoot 'docs/plans') -Filter '*.md' -File |
            Where-Object { $_.BaseName -notin @('README', '_template', 'BACKLOG', 'ACTIVE') } |
            Where-Object { $_.BaseName -notlike '*-report' } |
            Where-Object { (Get-Content -LiteralPath $_.FullName -TotalCount 20) -match '^Status:' }

        if (-not $candidates) {
            Write-Host 'snake: no template-conforming plans to lint (archived and legacy records are skipped).'
            exit 0
        }
        $bad = 0
        foreach ($file in $candidates) {
            try {
                $null = Invoke-OnePlan -Path $file.FullName -RepoRoot $repoRoot
            }
            catch {
                Write-Error "snake: $($file.Name): $($_.Exception.Message)" -ErrorAction Continue
                $bad++
            }
        }
        if ($bad -gt 0) { exit 1 }
        exit 0
    }

    $planPath = if ([System.IO.Path]::IsPathRooted($Plan)) { $Plan } else { Join-Path $repoRoot $Plan }
    if (-not (Test-Path -LiteralPath $planPath)) {
        if ($PSBoundParameters.ContainsKey('Plan')) {
            throw "snake: plan not found: $Plan"
        }
        # No ACTIVE.md. AGENTS.md's "no plan = no commit" is a rule for humans and
        # agents; it is not this script's job to fail a PR that has not opened one.
        Write-Host 'snake: no active plan (docs/plans/ACTIVE.md absent). Nothing to validate.'
        Write-Host 'snake: open one with  pwsh -NoProfile -File scripts/snake.ps1 -NextPlan'
        exit 0
    }

    $result = Invoke-OnePlan -Path $planPath -RepoRoot $repoRoot -Real:$real

    if ($Archive) {
        if (-not $result.Outcome) {
            throw 'snake: refusing to archive - ## Business outcome is empty. See docs/skills/business-outcomes.md.'
        }
        if ($result.Failed -gt 0) {
            throw 'snake: refusing to archive - steps or verify failed.'
        }
        Invoke-Archive -PlanObject $result.Plan -RepoRoot $repoRoot -Outcome $result.Outcome -PrNumber $Pr -CiState $Ci
    }

    Write-Report -PlanObject $result.Plan -RepoRoot $repoRoot -Mode $mode -Skills $result.Skills -Outcome $result.Outcome

    Write-Host ''
    Write-Host 'Jerry action required: none - agent may proceed on GO.'

    if ($result.Failed -gt 0) { exit 1 }
    exit 0
}
finally {
    Pop-Location
}
