# AGENTS.md

This repo is a Claude Code leash. Plans are law. Read the active plan before touching code.

Read `.ALLAGENTS.md` first, then `FLOW.md` for how work moves between the human,
the planning chat and the coding agent — including which screen a block belongs
on and what outranks what. Never transcribe repository state: run
`pwsh -NoProfile -File scripts/state.ps1`.

## Branch rules

| Branch | Rule |
| --- | --- |
| `main` | Releases only. Nobody writes directly. PR from `release/*` or `hotfix/*`. |
| `develop` | Integration branch. Everything lands here first, via PR from `feature/*`. |
| `feature/<name>` | One piece of work. Branched off `develop`, PR'd back into `develop`. |
| `release/<x.y.z>` | Freeze before a tag. Branched off `develop`. Merges to `main` and back into `develop`. |
| `hotfix/<name>` | Emergency fix to a tagged release. Branched off `main`. Merges to `main` and back into `develop`. |

No direct push to `main`. No direct push to `develop`. One feature = one branch = one PR.

## Plan rules

- The active plan lives at `docs/plans/ACTIVE.md` — a copy of the current feature's plan file.
- Before any edit, read `docs/plans/ACTIVE.md`. If it does not exist, or it does not name the
  branch you are on, **STOP** and report. Do not edit on a stale or missing plan.
- After any edit, update the plan's `## Progress` section. Do not leave it stale.
- On feature completion, move the plan to `docs/plans/archive/<date>-<slug>.md` and clear
  `ACTIVE.md`. Plans are archived, never deleted.
- No plan file = no commit.

## Tag rules

Annotated tags only. `git tag -a` is mandatory. Never create a lightweight tag.

Format: `plan/<slug>-YYYY-MM-DD`

Tag message template:

```
plan: <path>
branch: <name>
pr: #<n>
ci: green | red | skipped
outcome: <one line>
```

## Do not

- No Anthropic API calls in CI.
- No `--dangerously-skip-permissions`.
- No `LEDGER_HOOK_ARM`.
- No vendoring Ledger / Inspector / Policy into `src/` in a process-only plan.
- No `Co-Authored-By` trailers.
- No force-push.
- Never make this repo public.

## The human gate

Every report block ends with: `Jerry, click <PR link>, then Merge.` No ambiguity.

## Runtime

PowerShell 7.4+ is law. Run scripts with `pwsh -NoProfile -File <short-repo-relative-path>`.

---

## Leash image (run-01 / oneshot)

Everything below arrived with the run-01 / oneshot lineage and was merged in on 2026-09-21
when `origin/develop` met `feature/oneshot-2026-09-21`. Both sides are law. Where the two
disagree the stricter one wins, and the disagreements are listed at the end of this section.

The heading levels below are shifted one deeper so this file still has exactly one `#` title.

### Grok rules for claude.pwsh.image.builder

Grok loads this automatically. Short, specific, actionable. README for agents.

### Core behavior
- Sharp, unhinged, BASED AF partner. Dark humor, direct, no yes-man. Push back on bad logic.
- Read `.agent/TRAPS.md` (if present) at task start. Append only when a failure costs real time.
- Use `.agent/EXECUTION.md` (gitignored) as the live scratch log. Write as you go.
- Small diffs. No drive-by refactors. Match existing patterns.
- After changes: run verification and report raw output.

### Documentation as conversation
- Capture decisions, open questions, and traps while we talk.
- Decisions → `docs/DECISIONS/` as ADRs.
- Open questions → `docs/OPEN-QUESTIONS.md`.
- Failures → `.agent/TRAPS.md`.
- Per-run plan → `.agent/EXECUTION.md`.
- Every note linkable with real paths. Link to at least two existing nodes.

### Knowledge graph (Obsidian-style)
- Docs are a vault. Concepts, decisions, traps, questions = nodes.
- Use `[[wikilinks]]` or explicit markdown links.
- Tag: `#decision`, `#trap`, `#open-question`, `#architecture`, `#powershell`, `#build`, `#test`, `#image`, `#snake`, `#ledger`.
- Dense linking over long prose. Show clusters, not isolated blobs.

### PowerShell / image rules
- PowerShell 7.4+ is law. `#Requires -Version 7.4` on the module and every script.
- `$ErrorActionPreference = 'Stop'` and `$PSNativeCommandUseErrorActionPreference = $true` at the top of every script. Native command failures (docker, git) surface as terminating errors.
- Build is the only entry point: `Invoke-Build`. Never call `docker build`, `Invoke-Pester`, or `Invoke-ScriptAnalyzer` directly.
- The developer image enforces the shared plan contract: structured plan output, fail-first tests, skills-to-build.
- The snake (Ledger module) must be sucked into the builder so plan enforcement is real, not decorative.
- No stub files. No `# TODO` that ships. Fully implement or don't create.
- Verify before claiming. Report blockers immediately.

### Commands (discover, don't hardcode)
- `Invoke-Build Help` — grouped task catalog.
- `Invoke-Build ?` — flat engine list.
- `./build/ArgumentCompleters.ps1` — tab completion for tasks (dot-source in profile).
- Default chain: **Bootstrap → Build.Image → Test.InContainer → Goal.Update**.
- `Invoke-Build Quick` — host only, no image build. `Invoke-Build Full` — everything.
- `Test.FailFirst` is gone. It wrote its own test file, ran it, and treated any
  failure as success — including "command not found", which is what it actually
  got. Do not bring it back. `tests/*.Tests.ps1` is the suite.

### Every run ends with END_GOAL.md — MANDATORY, every agent, no exceptions

`Goal.Update` is the last task in the default chain and it **fails the build**
unless the run documented itself. This applies to Grok, Claude, Fable and
anyone else who touches this repo.

Before you claim a run is finished, `END_GOAL.md` must contain a section headed

```
### <yyyy-MM-dd> <git rev-parse --short HEAD> <run-id>
```

dated today, naming a commit on the current branch, and containing all of:

| Field | What goes in it |
|---|---|
| `Changed` | what this run actually changed |
| `Tested` | Pester totals as `passed=<n> failed=<n> skipped=<n>` |
| `Failed` | what is red, or `none` |
| `Missing` | what the run did not deliver |
| `Blockers` | every standing blocker, listed again every run |
| `Ledger head hash` | 64 hex chars, or `unavailable: BLOCKER-n` |
| `Assessment hash` | the canonical sha256 of the run's assessment |
| `COMBINED hash` | the last line of the run's `HASHES.txt` -- one sha256 over every artifact the run produced |

`Goal.Update` cross-checks the `Tested` totals against
`output/incontainer.json`. A report claiming a green run that did not happen
fails the build rather than being believed. Do not edit the numbers to match
the prose; rerun the chain.

It then appends one record to `.continuity/forensic.jsonl` via
`scripts/forensic.ps1`, which is a byte-identical copy of the one in
`claude.build.ledger` so both repos' chains share a format and a verifier.
Verify with `pwsh -NoProfile -File scripts/forensic.ps1 -Verify`, and print the
off-tree anchor with `-Anchor`.

**The blockers get listed every single run until someone decides otherwise:**
no signing key (identity is operator-asserted), and command-hook timeout fails
open.

A third stood here until 2026-09-23 — the Ledger's receipt-append function was
not exported, so the sentinel reached it through module session state. Someone
decided otherwise, which is the exit this rule already provides for. At vendor
pin `a68664e` the function is exported (`ledger.psd1:9`,
`ledger.psm1:1121-1122`) and `hooks/sentinel.ps1` calls it plainly. It is struck
from the standing list rather than relisted; the retirement is on the forensic
chain at seq 9, `blocker-1-retired`.

### Breadcrumbs for the other two (Claude + Fable)
- This build surface is NEW. Claude (Opus 5) and Fable (5.1) should pick up the plan contract, the fail-first discipline, and the snake integration from here.
- If they did their jobs right, the structured plan format and the skills-to-build list should be captured in `plans/` and `skills/` and implemented once they ask Jerry.
- If they don't, they're failing at their jobs. The tree will show it.
- Ledger snake lives in `claude.build.ledger` (sibling). The builder must consume it, not reimplement it.
- Continuity: `claude.build.ledger/docs/continuity.md` and `.grok/rules/continuity.md` are the shared memory. Read them.

### Grok-specific
- Check `~/.grok/` and `.grok/rules/*.md`.
- Nested `AGENTS.md` scopes to subtree.
- `grok inspect` to verify loaded rules.
- One-off: `grok --rules "..."`.

---

### Where the two sides disagree

Listed, not silently reconciled. Each line says which rule governs today and why. Several are
already carried as findings in `docs/plans/2026-09-21-compliance-pass/PLAN.md`; the finding
number is given where one exists.

| # | The disagreement | Governs today |
|---|---|---|
| 1 | The preamble says read `.ALLAGENTS.md`, then `FLOW.md`, and never transcribe state — run `scripts/state.ps1`. **None of those three files exist on this lineage.** | **SUSPENDED.** An instruction naming an absent file is unfollowable, not strict. It stays written down because deleting it would hide that `develop`'s CI still requires all three (FINDING-M4). Either the files come back or the rule goes — that is a decision, not a merge. |
| 2 | Plan rules require `docs/plans/ACTIVE.md`, say to **STOP** if it is missing, and end with "No plan file = no commit". This row used to end `ACTIVE.md` does not exist here, and that was false from the birth commit `f1aeb60` onward - the file arrived with the birth, naming `feature/env-local`. | **REINSTATED 2026-09-23, with a reading.** No `ACTIVE.md` means no active plan, and that is a legal state: the **STOP** fires only when the file EXISTS and names a branch other than the one you are on. `ACTIVE.md` is deleted in the same commit as this row, so the STOP is quiet today rather than suspended, and the next plan drafted into that path arms it again. What the suspension was covering: four merged pull requests each edited this tree while `ACTIVE.md` named `feature/env-local` and `HEAD` did not - #1 `b03aa76`, #2 `66a78d6`, #3 `3e47c9e`, #4 `bcd8fa4`. `scripts/snake.ps1:590-592` already read the rule this way; `scripts/state.ps1` is corrected to it here. The Plan rules prose at lines 24-31 and `FLOW.md` lines 187-188 still say STOP-if-missing and are NOT edited: this table is where the reading lives, which is the whole point of listing disagreements instead of silently reconciling them. |
| 3 | The oneshot side names `.agent/TRAPS.md`, `.agent/EXECUTION.md`, `docs/DECISIONS/` and `docs/OPEN-QUESTIONS.md`. None exist. (F-29) | **SUSPENDED.** Same class, other side. Neither lineage gets to pretend its missing files are only the other one's problem. |
| 4 | `## Do not` forbids `LEDGER_HOOK_ARM`; `README.md`'s `docker run` example passes `LEDGER_HOOK_ARM=1`, and nothing in this repo reads it. (F-27) | **The prohibition governs.** The README is wrong and is rebuilt later in this pass. |
| 5 | `No Co-Authored-By trailers` appears only on the develop side. | **It governs**, on both. The stricter rule wins, and it is the one this repo's CI can actually check. Every commit carries `who: <actor>` as its last line instead. |
| 6 | Branch rules mandate `release/*` and `hotfix/*`. Neither exists; work goes `feature/* -> develop -> main`. | **Both true.** The extra branch classes are unused, not forbidden. Nothing is dropped. |
| 7 | Both sides say "PowerShell 7.4+ is law", while the in-container runtime floor is 7.6. (BLOCKER-6) | **No contradiction between these two files.** 7.4 is the *script* contract, 7.6 is the *runtime* floor. They are different things that happen to look alike, which is exactly why BLOCKER-6 asks for one authoritative location. |
