# scripts

## state.ps1 — live state, so nobody types it by hand

```
pwsh -NoProfile -File scripts/state.ps1
```

Prints branches, SHAs, open and merged PRs with their required merge order, CI
conclusions, tags, repository merge settings, the active plan, and a preview of
what the CI guards would say. Output is a paste-ready block for a planning chat.

**It is read-only.** The only thing it changes is remote-tracking refs, via
`git fetch --prune` — without that its output would be confidently wrong, which
is the failure it exists to prevent. Pass `-NoFetch` to skip that when offline.

It refuses to run outside a clone of this repository, because the sibling
projects under `..` are one `cd` away and reporting
their state as this one's would be worse than reporting nothing.

Use it before your first action in a session, and before writing any plan's
`## Context`. Its output outranks any pasted state block — see `FLOW.md` §0.

## snake.ps1 — the orchestrator

The snake reads a plan, checks the skills it names exist, runs or dry-runs it,
writes the report, and drafts the next plan from the backlog. It is the part that
makes the loop self-sustaining: the plan stops being a static document and starts
being a thing that gets checked.

It is **dry-run-first**. The default is a dry run. Real execution requires both
`-Execute` and `-Go`, where `-Go` stands for the human having said GO. The snake
never merges, never pushes, and never creates a tag without `-Go`.

### Usage

```
# validate the active plan and show what would run (the default)
pwsh -NoProfile -File scripts/snake.ps1 -DryRun

# same, with the internals on screen
pwsh -NoProfile -File scripts/snake.ps1 -DryRun -Verbose -Debug

# lint every template-conforming plan in docs/plans/
pwsh -NoProfile -File scripts/snake.ps1 -DryRun -All

# execute for real — requires the human GO
pwsh -NoProfile -File scripts/snake.ps1 -Execute -Go

# close the plan out: archive, clear ACTIVE.md, annotated tag
pwsh -NoProfile -File scripts/snake.ps1 -Archive -Go -Pr 2 -Ci green

# draft the next plan from docs/plans/BACKLOG.md into ACTIVE.md (never commits)
pwsh -NoProfile -File scripts/snake.ps1 -NextPlan
```

### Parameters

| Parameter | Effect |
| --- | --- |
| `-Plan <path>` | Plan to read. Default `docs/plans/ACTIVE.md`. |
| `-DryRun` | Print what would run. This is the default behaviour. |
| `-Execute` | Run the plan's fenced steps and verify blocks. Requires `-Go`. |
| `-Go` | The human GO. Required by `-Execute` and `-Archive`. |
| `-Archive` | Archive the plan, clear `ACTIVE.md`, create the annotated tag. |
| `-NextPlan` | Draft the next plan from the backlog. |
| `-All` | Lint every template-conforming plan instead of one. |
| `-Pr`, `-Ci` | Fill the `pr:` and `ci:` lines of the tag message. |

### What it enforces

- **Required sections.** A plan missing any of `Goal`, `Context`,
  `Business outcome`, `Skills referenced`, `Allow-list`, `Do-not-touch`, `Steps`,
  `Verify`, `Progress`, `Report block`, `Jerry action required` is exit 1.
- **Skills exist.** A plan naming a skill with no `docs/skills/<name>.md` is a
  STOP, not a warning.
- **Outcome is not empty.** `-Archive` refuses a plan whose `## Business outcome`
  is blank or still holds the template placeholder.
- **Annotated tags only.** The snake only ever calls `git tag -a`.

### Two deliberate leniencies

1. **No `ACTIVE.md` is not an error in a default dry run.** It reports "no active
   plan" and exits 0. AGENTS.md's "no plan = no commit" is a rule for humans and
   agents; failing every PR on a branch that has not opened a plan yet would just
   train people to ignore red CI.
2. **Archived and legacy plans are not linted.** `-All` only picks up plans that
   opt in with a `Status:` line. An archived plan is an immutable record of what
   was authorised at the time — re-linting it against a newer template would
   invite editing history to make a tool happy.

### In CI

`.github/workflows/ci.yml` runs `scripts/snake.ps1 -DryRun` on every PR. That
proves the snake parses and the active plan is well-formed. It executes nothing.
