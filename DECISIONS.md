# Decisions

Decisions that change what this repository keeps, and why. Each one points at the forensic record
that carries its evidence. Newest first.

## 2026-09-24 - Which merge commits have a ci run, and what the evidence is where they don't

**Context.** Automerge (`.github/workflows/automerge.yml`, `scripts/Invoke-AutoMerge.ps1`) merges with the
workflow's `GITHUB_TOKEN`. GitHub starts no workflow for a push made with that token, and a merge is a
push. So an automerged merge commit gets no `ci` run of its own, on either branch. `workflow_dispatch`
is the exception. Measured on 2026-09-24 through the Actions API, for every first-parent merge:

| branch | merge commits | merged by | `ci` runs on the merge commit itself |
|---|---|---|---|
| `main` | `994adf8` (#7), `249752d` (#11), `6b8943a` (#15) | `github-actions` | **none** |
| `main` | `bc7b64c` (#23) | `github-actions` | one: 35957396113, dispatched **by hand** by claude, *failure*, on the self-referential check fixed in #24 (forensic seq 42) |
| `develop` | `b03aa76` (#1) | JerryBalmer1 | one, a `push` run: a merge made with a person's token starts workflows |
| `develop` | every other merge, #2 to #27 | `github-actions` | none of its own |

Four `develop` merge commits (`ac6f167`, `85d9066`, `74c1db2`, `28eeed2`) show one `pull_request` run each.
Those aren't runs of `develop`. Each was the head of a promotion PR (#7, #11, #15, #23), and that is
the promotion's own check.

**Decision, main.** `6b8943a` and every automerged promotion before it have **no `ci` run on `main`**,
and none will be manufactured. `bc7b64c` has one run, which failed, and it stays as it is. The repair
is `Invoke-CiDispatchOnMain` (`scripts/AutoMerge.Lib.ps1`, I12 PR 3): after a merge into `main`,
automerge dispatches `ci.yml` on `main`. Automerge's `workflow_run` runs `main`'s copy of itself, and
the dispatch first reached `main` in `bc7b64c`. **So the I13 promotion is the first whose merge can
dispatch, and from it forward `main`'s tip has a `ci` run.** Whether that first dispatch happened,
and how it concluded, is measured in the I13 promotion's forensic record, not asserted here.
`tests/CiOnMain.Tests.ps1` measures the tip live on every run. If a dispatch ever fails, that test
goes red rather than the gap going quiet.

**Decision, develop.** Automerged merges into `develop` have the same gap, and **it is not closed.**
The dispatch is deliberately `main`-only, because a run per `develop` merge would duplicate what
already ran. The evidence for a `develop` merge is its PR's checks. A `pull_request` run tests
`refs/pull/<n>/merge`, the PR head merged onto `develop` as it stood when the run started. Automerge
reads those check-runs on the head commit and merges only when every `required_checks` entry is
`success`.

**Limit of that evidence, stated.** Automerge does not check whether `develop` moved after the run
started. If another PR lands in between, the merge commit's tree is a combination no run tested.
Nothing in this repository requires the branch to be up to date, and branch protection is not part of
this claim (`AGENTS.md`). In practice PRs here land one at a time, and a later promotion PR's run tests
the combined `develop` onto `main`. That narrows the gap but doesn't close it.

This entry is the written trail for readers of the public repository. It changes no code.

## 2026-09-24 - 23b1db9: a one-pair edit list unrolled into two one-character replacements

**Context.** `23b1db9` (I12 PR 1) meant to change one line of `END_GOAL.md` and changed 658: every `a`
became a space and every backtick became `j`. #21 repaired the file and said how it happened was not
established. It is now. The edit was one inline pwsh command, found in the I12 session transcript two
minutes before the commit. Its entry for this file was

```powershell
@{ F = 'END_GOAL.md'; P = @( @('<old>', '<new>') ) }
```

**The bug.** PowerShell's array subexpression operator `@()` unrolls an array it contains, so
`@( @(a, b) )` is `@(a, b)`. `P` held two strings, not one pair. `foreach ($p in $e.P)` walked the
strings, and `$p[0]`, `$p[1]` indexed characters. The first string begins with a backtick followed by
`j`, and the second begins with `a` followed by a space. So the loop replaced every backtick with `j`,
then every `a` with a space. The anchor check `Contains($p[0])` passed, because a single character is almost
always present. Every other file in the same command had two or more pairs, which stay pairs. That is
why only `END_GOAL.md` was damaged, which #21 had measured without knowing why.

**Reproduced, not inferred.** The exact entry and loop, run in a temp folder on `23b1db9~1`'s blob
`b017750`, produce blob `54901e2`, which is `23b1db9`'s blob, byte for byte (658 lines changed, 658 removed).
Of the packet's suspects, this is closest to "char arithmetic in a loop". No cast was written, though:
the characters came from indexing a string the author believed was a pair. No `-replace` pattern,
encoding or CRLF handling was involved.

**Decision.** A scripted edit to a tracked text file goes through `scripts/Edit-Text.ps1`. It takes
parallel `-Old` and `-New` arrays, so there is no pair shape to unroll. Every old string must occur
exactly once. The line diff is measured on a copy, printed, and compared with the caller's declared
`-ExpectAdded` / `-ExpectDeleted` before anything is written. `tests/ScriptedEdit.Tests.ps1` pins the
reproduction and shows the tool refusing `23b1db9`'s inputs. Where a literal holding one pair is
really needed, it is written `@( ,@(a, b) )`.

**Retired from the tree: no sites.** The pattern lived only in that inline command. Every tracked
`.ps1` and `.psm1` was searched for pair indexing. `scripts/Generate-Policy.ps1:112,211` and
`scripts/ci/Test-BranchFlow.ps1:48,52,61` index `$config.flow` rows from `ConvertFrom-Json`, where a
one-row array stays a row (measured). `scripts/Invoke-AutoMerge.ps1:140` indexes a `-split` result.
None is a nested literal, and none edits a file. `FINDINGS.md` I13-F1. Forensic chain seq 46.

## 2026-09-24 - src/LedgerReceipt.ps1 deleted: shipped in both images, called by nothing

**Context.** Both images copy `src/` into `/opt/leash/src/`. `src/LedgerReceipt.ps1` defined
`Invoke-LedgerBootVerify` and `Test-SentinelChain`, and nothing in the tree dot-sourced it or called
either function: not `entrypoint.ps1`, not the sentinel, not the build. I11 fixed two defects in it,
a dead ledger path and an `if` in plain parentheses that threw inside the image. Both were found by
reading the file, not by anything running it, which is the point. Receipts are written by the
sentinel through core's `Add-LedgerRecord`. Neither `AGENTS.md` nor `END_GOAL.md` names this file as
a required receipt writer; that was checked before deleting.

**Decision.** Delete the file and its behavioural test. `tests/ShippedScripts.Tests.ps1` now requires
every script under `src/` to have a caller outside `tests/`, so the next one is caught when it lands.

**Not changed, and why.** Both Dockerfiles keep `COPY src/ /opt/leash/src/`. There never were
lines copying this file by name, and `src/` still ships `src/PlanValidator.ps1`, which
`build/tasks/Plan.build.ps1` calls. Deleting the file removes it from both images through that line.
Forensic chain seq 40.

## 2026-09-24 - Public hygiene: forensic records keep what they say

**Context.** The repository is public. I12 PR 1 scanned every tracked file at `e195e49`, including
`.continuity/`, for local user paths, email addresses, tokens or private keys, and the name of the
private origin repository that several scripts were copied from. The scan found no user paths and no
tokens or keys. It found one email address and 36 occurrences of the private repository's name in live
files, all edited. `tests/PublicHygiene.Tests.ps1` now fails on any of the four in a tracked file
outside `.continuity/`.

**Decision.** Hits inside forensic records are **not** edited. A forensic record's `self` is a sha256
over its own bytes and the next record's `prev` points at it. Editing one word breaks every link after
it. Rewriting the chain to repair that would destroy the only property the chain has. The records stay
exactly as written, and are listed here instead:

| seq | subject | what it carries |
|---|---|---|
| 1 | `claude-agent-images-birth` | the private origin repository's name, once |
| 4 | `<name>-path-coupling-to-core` (the subject begins with the name) | the name, twice: in the subject and in the evidence |
| 8 | `prebirth-tests-retired` | the name, once |
| 12 | `tidy-before-promotion-six-items` | the name, twice |
| 16 | `repo-public-by-decision` | the name, once |
| 17 | `promotion-develop-to-main-994adf8` | the name, twice |
| 23 | `promotion-develop-to-main-249752d` | the name, once |
| 29 | `public-hygiene` | the name, once, in the decision that opened this pass |
| 19 | `stale-premises-five-items` | a personal address written as `<user> at gmail`, not in address form, so the scan's email pattern did not match it. Listed because it is the same disclosure. |

A finding record at seq 30, `public-hygiene-records-not-edited`, points at this list.

**Not clearable without a history rewrite, and not attempted:** git commit metadata carries personal
author addresses (for example `eefebd8`), and earlier blobs of `END_GOAL.md` hold the address that
line 291 named until this pass. Neither is a tracked file at the tip. This repository never rewrites
history. Stopping the forward leak is an identity setting, and it is Jerry's to change.

**Licence.** MIT, JerryBalmer1, 2026, in `LICENSE`, stated in one line of `README.md`.
