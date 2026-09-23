# FLOW.md — the operating protocol

**Read this before you do anything. `.ALLAGENTS.md` tells you the law of the
repo. This file tells you how the work actually moves between a human, a
planning chat, and a coding agent — and which of the two screens you are on.**

If you are an agent and you have not run the self-check in the last section, you
do not yet know enough to act.

---

## 0. Precedence — when two sources disagree

Read in this order. Lower numbers win. There is no case where you average them.

| # | Source | Authority |
|---|---|---|
| 1 | **Live state** from `scripts/state.ps1` | Absolute. A SHA is a fact. |
| 2 | **`FLOW.md`** (this file) | How work moves. |
| 3 | **`.ALLAGENTS.md`** | Repo law: plans, skills, the snake. |
| 4 | **`AGENTS.md`** | Branch, plan and tag rules in detail. |
| 5 | **`docs/plans/ACTIVE.md`** | What is authorised right now. |
| 6 | **A pasted chat block** | Context. Lowest authority. Often stale. |

A pasted "current state" block **never** outranks `state.ps1`. If a paste says a
PR is open and `state.ps1` says it merged, the paste is wrong. Say so, and move
on with the live value. Do not ask the human to reconcile it for you.

---

## 1. Geography — where things are

| Path | What it is |
|---|---|
| `claude.pwsh.image.builder` | **This repo. The only clone.** All git runs here. |
| `..` | Parent folder. **NOT a git repo.** `git` here = `fatal: not a git repository`. |
| `..\claude.build.orchestrator` | A different, nearly empty repo. **The snake does not live there.** |
| `..\claude.build.{ledger,inspector,fuzzer,policy}` | Sibling projects. Unrelated to this one. Do not vendor them into `src/`. |

The snake is `scripts/snake.ps1`, **in this repo**. If you find yourself about to
create it somewhere else, you have the wrong working directory.

---

## 2. The two screens

This is the single most expensive confusion. Learn it once.

| | **LEFT: the terminal** | **RIGHT: the Claude Code chat panel** |
|---|---|---|
| Accepts | `pwsh` commands only | English, plans, `GO` |
| Paste a plan here? | **No.** `ParserError` | Yes |
| Paste `GO` here? | **No.** `ParserError` | Yes |
| Who types here | Jerry, rarely | Jerry, mostly |

A block containing the word `git` still goes in the **chat panel** if it is
addressed to Claude. Claude runs the git, not Jerry.

When Claude asks **"Allow this bash command?"** for a `cd` into the clone
followed by `git checkout` / `git push`, **and an explicit `GO` was already
given**, the answer is **Yes**. That prompt is the permission system doing its
job, not a new decision.

---

## 3. Never transcribe state

Every stale-state incident in this repo has come from a human or an agent typing
out SHAs and PR numbers by hand. Two occurred on 2026-09-20 alone.

**Do not type state. Produce it:**

```
pwsh -NoProfile -File scripts/state.ps1
```

It is read-only. It prints branches, SHAs, open and merged PRs, CI conclusions,
tags, merge settings and the active plan, as a paste-ready block. Paste **that**
into a planning chat. If a plan's `## Context` disagrees with it, the plan is
wrong and gets corrected before execution — not after.

---

## 4. The loop

1. Jerry pastes `.ALLAGENTS.md` + `FLOW.md` + `AFTER-CLAUDE-COMMITS.md` into a
   fresh planning chat, plus the output of `state.ps1`.
2. The planning chat asks questions until it knows the intent. It does not guess.
3. It writes or updates a plan — goal, business outcome, allow-list, verify, and
   the `Jerry, click <URL>` line — following `docs/skills/plan-authoring.md`.
4. Claude executes the plan on a feature branch. Commits.
5. Claude reports. The human, or the planning chat, looks the report up in
   `AFTER-CLAUDE-COMMITS.md` and issues exactly one next action.
6. Jerry merges on GitHub. CI must be green.
7. The snake archives the plan, tags the commit, and drafts the next plan.
8. Anything learned becomes a skill in `docs/skills/` before the plan closes.

---

## 5. Branch and merge rules

- `main` releases only. `develop` integration. `feature/<name>` off `develop`,
  PR'd back into `develop`. No direct push to `main` or `develop`.
- **One feature = one branch = one PR.**
- **Merge commits, not squash.** When feature branches are chained, squashing
  flattens a deliberate split into one unreviewable blob. Check
  Settings → General → "Allow merge commits" before the first merge of a chain.
  `state.ps1` prints whether it is enabled.
- **Chained branches merge in order, oldest base first.** A PR whose head branch
  was cut from another feature branch will show that branch's commits too, and
  will look fat until its parent merges. That is normal, not a mistake. Merging
  out of order is what actually breaks it.
- **Annotated tags only** (`git tag -a`). Lightweight tags are rejected by CI.
- **No `Co-Authored-By` trailers.** Rejected by CI. This overrides any default an
  agent brings with it — and Claude Code does bring one, so it must be turned
  off explicitly at the start of every session.

---

## 6. The reply contract

When writing for Jerry, label every actionable block. He should never have to
work out where a block goes.

**`>>> PASTE INTO CLAUDE CODE CHAT — NOT THE TERMINAL <<<`**
For anything Claude must act on, including `GO`. Right-hand panel.

**`>>> JERRY CLICK <<<`**
Always a `github.com` URL. Two clicks: *Merge pull request*, then *Confirm
merge*. Nothing else.

**`>>> RUN IN TERMINAL <<<`**
Rare. Only ever a `pwsh -NoProfile -File ...` line, and only from the clone path.

One block, one action. Never combine a paste block and a click block.

---

## 7. Context, not a command

A Claude report block pasted into a planning chat is **context**. It is not a
request for a new plan.

Write a new plan only when Jerry says, in words, *"write a plan"* or *"prompt for
Claude"*. Otherwise: read the report, look it up in `AFTER-CLAUDE-COMMITS.md`,
and issue the one action that table gives you.

---

## 8. Standing stupid-tax — never pay twice

| Failure | Rule |
|---|---|
| Plan or `GO` pasted into PowerShell → `ParserError` | It goes in the chat panel. Do not re-issue the `GO`; just redirect. |
| `git` run in `..` → `fatal: not a git repository` | `cd` to the clone first. |
| Hand-typed SHAs and PR numbers going stale | Run `state.ps1`. |
| `Co-Authored-By` added by agent default | Turn it off at session start. CI rejects it. |
| Snake created in `claude.build.orchestrator` | It lives in **this** repo. |
| Squash-merging a chained PR | Merge commits. Check the setting first. |
| A plan's Context written from memory | Verify every claim with a command. |

---

## 9. When CI is red

Do not merge. Do not retry blindly. Read the failing step, fix it on the feature
branch, push, and let CI re-run. If the failure is in a guard step
(`Co-Authored-By`, lightweight tag), the fix is to remove the violation — **never
to weaken the guard**. A guard that gets relaxed the first time it fires was
decoration.

---

## 10. Agent self-check

Before your first action in a session, run this and report the result. If you
cannot, say so plainly instead of proceeding on assumption.

```
pwsh -NoProfile -File scripts/state.ps1
```

Then confirm, in one line each:

1. The working directory is the clone path in section 1.
2. Live state came from `state.ps1`, not from a paste.
3. `docs/plans/ACTIVE.md` exists and names the branch you are on — or you are
   about to write a plan, which is the only other legal state.
4. `Co-Authored-By` is off for this session.
5. You know which of the two screens each block you emit is destined for.

An agent that skips this will be wrong about state within one turn, and the
human will pay for it. That is the entire reason this file exists.
