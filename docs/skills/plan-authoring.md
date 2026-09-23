---
name: plan-authoring
triggers: Any new feature branch, any request that would change a tracked file, any session that starts with "can you just…". If you are about to edit code and there is no ACTIVE.md naming your branch, you are here.
inputs: The human's request, the current repo state (branches, tree, CI), the skills index, the backlog.
outputs: A plan file at docs/plans/<date>-<slug>.md, copied to docs/plans/ACTIVE.md, committed BEFORE any code change.
do-not: Do not start coding to "see what's involved" and write the plan after. Do not widen the allow-list mid-execution. Do not omit the Jerry action header. Do not reconstruct a prior plan's text from memory.
learned-from: 2026-09-20-skill-factory (the plan that built the snake); hardened by 2026-09-20-ci-green (plans-as-accountability) and the reconcile that found three false preconditions in a plan's Context section.
---

# plan-authoring

## When to use

Before any code changes. The plan file is committed first, and it is the thing
the snake parses, the human approves, and the archive preserves. A plan written
after the fact is a changelog, not a plan — it cannot gate anything.

Use it also when a plan you were handed does not parse: rather than patching it
in your head, rewrite it to this shape and get it approved.

## Required sections

The snake's `Read-Plan` requires every one of these headers. A missing header is
exit 1, not a warning. Keep the headers even when a section is short — agents
grep for them.

| Section | What goes in it |
| --- | --- |
| `## Goal` | One paragraph. What "done" looks like, in outcome terms. |
| `## Context` | What exists, what broke, why now. **Verified, not remembered.** |
| `## Business outcome` | The OKR / milestone / risk it serves. See `business-outcomes`. |
| `## Skills referenced` | Bare skill names, one per line, `- ` prefixed. Each must exist. |
| `## Allow-list (only these paths may change)` | Exhaustive. If it is not listed, it does not change. |
| `## Do-not-touch` | The files a reasonable agent might otherwise "just fix". |
| `## Steps` | Numbered. Fenced code blocks are executable; prose steps are manual. |
| `## Verify (local, no commit)` | Commands that prove the work without committing. |
| `## Progress` | Updated after every change. Never left stale. |
| `## Report block` | The fixed shape below. |
| `## Jerry action required` | Ends with the literal gate line. |

## Steps

1. **Verify the Context before you write it.** Every claim about repo state gets
   a command behind it: `git fetch --all --prune`, `git status -sb`,
   `git log --oneline --all`, `gh pr list --state all`, `git tag -l`. A Context
   section that says "PR #1, merging now" when the PR merged an hour ago poisons
   every step downstream.
2. **Ask until you know the human.** Intent, constraints, success criteria. Where
   two readings of the request lead to materially different work, ask — do not
   pick one and hope. Record the answers in `## Context` so nobody asks twice.
3. **Write the allow-list before the steps.** The allow-list is the contract; the
   steps are just how you honour it. If a step needs a path that is not listed,
   the plan is wrong — stop and amend it, do not "just fix it".
4. **Name the skills.** Every skill this plan leans on goes in
   `## Skills referenced`. If you need one that does not exist, write the skill
   file in the same plan and list it in the allow-list.
5. **Run the compliance checklist** (below). Tick it explicitly, even when every
   answer is "not applicable" — the record is the point.
6. **Write the verify block as commands, not intentions.** "Confirm it parses" is
   not verifiable. `pwsh -NoProfile -File scripts/snake.ps1 -DryRun` is.
7. **Commit the plan file first**, on the feature branch, before any code change.
8. Execute. Update `## Progress` as you go.
9. Report. Stop at the human gate.

## Compliance checklist

Answer all five in the plan, in `## Context` or a dedicated subsection. "N/A" is
a valid answer; silence is not.

- **Secrets** — does this plan cause a credential, token, or key to be written,
  logged, echoed into CI output, or baked into an image layer?
- **PII** — does it move, store, or log personal data? If yes, name the lawful
  basis and the retention limit.
- **PCI** — does it touch cardholder data or anything in scope of a CDE? If yes,
  stop and get a human decision before writing steps.
- **Network egress** — does it add an outbound call, a new dependency source, or
  a download in CI or in the image? Pin it or justify it.
- **Blast radius** — what breaks if every step runs wrong? If the answer includes
  `main`, a published tag, or a shared environment, the plan needs a narrower
  allow-list.

## Report block

```
HEAD local:        <sha> <branch>
origin/main:       <sha>
origin/develop:    <sha>
Working tree:      clean | dirty
Plan updated:      yes | no
Annotated tag:     none (until GO)
Merged:            no
Pushed:            no
Committed:         no
```

End every report with the gate:

```
Jerry, click <PR link>, then Merge.
```

If there is no human action: `Jerry action required: none — agent may proceed on GO.`
Never omit the header.

## Verify

```
pwsh -NoProfile -File scripts/snake.ps1 -DryRun
```

The snake parses the active plan, checks every named skill resolves, confirms the
business outcome is non-empty, and lists what the steps and verify block would
run. Exit 0 means the plan is well-formed. It does not mean the plan is correct —
only a human reading `## Goal` against `## Business outcome` can say that.

## Anti-patterns

- **Writing Context from memory.** The most expensive failure in this repo so far.
  Three preconditions in a handed-down plan were false; the branch it named would
  have stranded uncommitted work on two do-not-touch files.
- **The allow-list that says "and related files".** It is not an allow-list then.
- **Prose steps for executable work.** If the snake cannot run it, it is a manual
  step and must be labelled as one, so the human knows they are on the hook.
- **Widening scope mid-execution** because a fix is "right there". Stop, report,
  amend the plan, then continue. The plan is the authorisation.
- **Rewriting an archived plan** to match a newer template. Archived plans are
  immutable records of what was authorised at the time.
