# AFTER-CLAUDE-COMMITS.md — what to do with a Claude report

Claude ends every piece of work with a report block. This file turns that block
into exactly one next action. **Look it up. Do not reason about it.**

A report is **context, not a command**. It is never, by itself, a reason to write
a new plan. See `FLOW.md` §7.

---

## The lookup

Read these fields off the report block: `Committed`, `Pushed`, `Merged`, plus
whether a PR is open and what CI says. Find the first row that matches.

| # | Report says | State | Your one action |
|---|---|---|---|
| 1 | Report asks a question, or lists items under **Jerry action required** that are decisions | Blocked on a human | **Answer the questions.** Nothing else. Do not issue `GO`. |
| 2 | `Committed: no`, `Pushed: no` | Work not done, or stopped deliberately | Read *why* it stopped. Usually row 1. If it hit an error, send the error back. |
| 3 | `Committed: yes (local only)`, `Pushed: no` | Ready to publish | **CLAUDE PASTE — push + open PR.** Template A. |
| 4 | `Pushed: yes`, PR open, CI **pending** | In flight | **Wait.** Say "CI running." Issue nothing. |
| 5 | `Pushed: yes`, PR open, CI **green** | Ready for the human | **JERRY CLICK.** Template B. URLs only. |
| 6 | `Pushed: yes`, PR open, CI **red** | Broken | **CLAUDE PASTE — fix.** Template C. Never merge, never weaken the guard. |
| 7 | `Merged: yes`, plan still active | Needs closing out | **CLAUDE PASTE — archive + tag.** Template D. |
| 8 | `Merged: yes`, plan archived, tag exists | Cycle complete | Ask Jerry what is next, or draft from `docs/plans/BACKLOG.md`. |

If two rows seem to match, take the **lower-numbered** one. Row 1 always wins:
an unanswered question outranks everything.

---

## Before you use any template

Run `scripts/state.ps1` and use its values. Never copy a SHA or PR number out of
a chat message — that is the failure this repo keeps paying for (`FLOW.md` §3).

---

## Template A — push and open the PR

> \>>> PASTE INTO CLAUDE CODE CHAT — NOT THE TERMINAL <<<
>
> GO. Push the branch and open a PR into develop. Merge commit, not squash.
> No Co-Authored-By. No tags. Do not merge.
> Print the PR URL, then stop.

If several chained branches are waiting, name the order explicitly and say which
merges first. Do not leave the order implied.

## Template B — hand it to Jerry

> \>>> JERRY CLICK <<<
>
> PR #<n> — merge FIRST: <url>
> PR #<m> — merge SECOND: <url>
>
> Two clicks each: **Merge pull request**, then **Confirm merge**.

Only URLs and order. No commands in this block. If only one PR is open, drop the
ordering line rather than inventing a second.

## Template C — CI is red

> \>>> PASTE INTO CLAUDE CODE CHAT — NOT THE TERMINAL <<<
>
> CI is red on <branch>. Failing step: <name>.
> <paste the failing log lines>
> Fix it on the feature branch, push, and report. Do not merge.
> If the failure is a guard step, remove the violation — do not change the guard.

## Template D — close the cycle out

> \>>> PASTE INTO CLAUDE CODE CHAT — NOT THE TERMINAL <<<
>
> GO. The PR is merged and CI is green. Archive the plan and create the
> annotated tag:
> `pwsh -NoProfile -File scripts/snake.ps1 -Archive -Go -Pr <n> -Ci green`
> Do not push the tag unless I say so. Report, then stop.

---

## Things that are not next actions

- **Writing a new plan** because the report was long. See `FLOW.md` §7.
- **Re-issuing `GO`** because Jerry pasted it into the terminal and got a
  `ParserError`. The `GO` was valid; the panel was wrong. Redirect him.
- **Saying "looks good"** with no labelled block. Every reply that expects an
  action carries exactly one labelled block.
- **Merging out of order** in a chain. The second PR looking fat is expected
  until the first lands.
- **Tagging before the merge.** Tags are created after merge, by row 7, never
  before.

---

## Sanity checks on the report itself

A report that fails any of these is telling you something is wrong upstream:

- `Working tree: dirty` at the end of a completed step — uncommitted work is
  about to get stranded. That has happened here before. Ask before moving on.
- Paths changed that are **not** on the plan's allow-list — the plan was widened
  without authorisation. Stop and ask.
- `Annotated tag:` anything other than `none` before a merge — a tag was created
  early. Stop and ask.
- A SHA in the report that `state.ps1` does not agree with — trust `state.ps1`.
