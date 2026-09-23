---
name: business-outcomes
triggers: Writing a plan's "## Business outcome" section; closing or archiving a plan; any time someone says "done" about work whose outcome has not moved.
inputs: The plan's Goal, the current OKR or milestone, the risk register if one exists.
outputs: A non-empty "## Business outcome" section naming a measurable outcome, and a closing judgement of whether that outcome was met.
do-not: Do not restate the Goal as the outcome. Do not write "improves quality" or "makes things easier" — those are not outcomes. Do not close a plan on "code written".
learned-from: 2026-09-20-skill-factory (the plan that built the snake).
---

# business-outcomes

## When to use

Every plan, without exception. The outcome section is what separates a repo that
ships from a repo that is busy. The snake enforces it mechanically: `-Archive`
refuses to close a plan whose `## Business outcome` is empty or still holds the
template placeholder.

## What counts as an outcome

An outcome is a change in the world outside this repo, or a measurable change in
the cost of operating it. It has a direction and, where possible, a number.

| Category | Example | Not an outcome |
| --- | --- | --- |
| OKR | "KR2: agent onboarding under 30s — this closes it" | "Supports the OKRs" |
| Milestone | "Unblocks the sentinel image experiment" | "Progress on the image" |
| Revenue | "Demoable leash for the compliance conversation" | "Looks more professional" |
| Risk reduction | "Removes the class of failure where an agent edits the gate" | "Safer" |
| Cost / friction | "Kills the 10-minute re-explain at the start of every session" | "Nicer DX" |

If you cannot put the plan in one of those rows, that is a signal about the plan,
not about the table.

## Steps

1. Before writing steps, write the outcome. If the outcome will not move, the
   plan does not need to exist — say so and stop.
2. Name the measure. "Under 30 seconds", "zero manual re-explanations", "CI green
   on every PR without a human touching the runner". A measure you cannot check
   at close time is not a measure.
3. Name who benefits, in one clause. If the answer is only "the agent", look
   harder — an agent's convenience is only an outcome when it converts to the
   human's time or the product's risk.
4. At close, judge the outcome explicitly: **met**, **partially met** (say which
   part), or **not met** (say why, and whether the plan was wrong or the work was).
   Write that judgement into `## Progress` before archiving.
5. If the outcome was not met, the next plan inherits it. Put it at the top of
   `docs/plans/BACKLOG.md`.

## Definition of done

Done means the outcome is met. It does not mean:

- the code is written,
- the tests pass,
- CI is green,
- the PR is merged.

Those are necessary and none of them are sufficient. A merged PR whose outcome
did not move is a plan that failed quietly — the most expensive kind, because it
looks like progress in the log.

## Verify

```
pwsh -NoProfile -File scripts/snake.ps1 -DryRun
```

The dry run reports the outcome section it found. At close time,
`scripts/snake.ps1 -Archive -Go` refuses to archive an empty or placeholder
outcome, so a plan cannot be filed away without a stated result.

## Anti-patterns

- **Outcome as restated goal.** "Goal: build the snake. Outcome: the snake is
  built." That is a tautology wearing a tie.
- **Unfalsifiable outcomes.** "Better developer experience." Nobody can ever say
  it was not met, which means nobody can ever say it was.
- **Retrofitting the outcome at close** to match whatever happened. Write it
  first; if it turns out wrong, say it was wrong.
- **Counting activity.** Commits, lines, files, plans closed. All inputs. None of
  them are the thing.
