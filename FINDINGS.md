# Findings

Defects found in this repository: what they did, what caused them, and what catches them now. Each
one points at its forensic record and, where one exists, the decision in `DECISIONS.md`. Newest first.

## Carried from image.builder: the cleanup findings nothing here cites

`claude.pwsh.image.builder` kept its own findings for the 2026-09-21 cleanup, M1 to M17, in
[`image.builder@5f71173:docs/plans/2026-09-21-cleanup/FINDINGS.md`](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md)
at `5f71173`. That file never came into this tree. Nine of the seventeen are cited from a live repository: M4, M6,
M7, M8, M13 and M17 here, and M1 to M3 in the docs vault. The eight below were cited nowhere, measured 2026-09-24 with
`git grep -nwE '(FINDING-)?M<n>'` over core, images and tools at `origin/develop` and over the vault. Each one is carried
as a link and a status measured against `origin/develop` at `15ee3c4`. The text stays where it was written.

| Finding | What it recorded | Status here |
|---|---|---|
| [M5](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md#L104-L108) | two diff counts, 92 and 46, were of different pairs, and neither corrects the other | **closed**. A record about two numbers, with nothing to fix |
| [M9](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md#L155-L184) | a Pester title with `<name>` and no `-ForEach` threw under strict mode; that suite had never run in CI | **fixed, carried**. The title is `.env.ANYNAME.local is ignored` at `tests/Env.Tests.ps1:81` |
| [M10](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md#L186-L227) | git refused the bind-mounted `/work` as dubious ownership; `-c` and `GIT_CONFIG_COUNT` can't carry `safe.directory` | **fixed, carried**. `build/container.gitconfig` is passed as `GIT_CONFIG_GLOBAL` at `build/tasks/Test.build.ps1:80`, and baked into neither image |
| [M11](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md#L229-L251) | `scripts/env.ps1` identified the repository by its folder name | **fixed, carried**. `scripts/env.ps1:73` resolves the root from `$PSScriptRoot` |
| [M12](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md#L253-L268) | the in-container count was 138, not the 109 the run order expected; a test assumed `LEASH_REQUIRE_CLAUDE` unset | **closed**. The count is history, and the test fix is carried: `tests/Entrypoint.Tests.ps1:237` clears the variable explicitly |
| [M14](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md#L288-L312) | the CI port dropped three guards: docker build smoke, annotated tags only, hadolint | **partly open**. Docker build is restored by the `images` and `incontainer` jobs (`.github/workflows/ci.yml:71`, `:135`). Annotated tags are reported by `scripts/state.ps1:300` and enforced by no check. hadolint is open: `.hadolint.yaml` is tracked and nothing runs it |
| [M15](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md#L314-L350) | the automerge that reads its config from the base can't merge the PR that introduces that config, and a 404 crashed it | **fixed, carried**. `Get-RepoConfigAtRef` returns `$null` on a failed read (`scripts/AutoMerge.Lib.ps1:101`, `:106`). The bootstrap cost is permanent by design |
| [M16](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/docs/plans/2026-09-21-cleanup/FINDINGS.md#L352-L376) | CI checked out no submodule, and the failures read as product defects | **fixed, carried**. `submodules: recursive` at `.github/workflows/ci.yml:76`, `:115` and `:150` |

## Pre-images chain: image.builder's five forensic records

`claude.pwsh.image.builder` kept a forensic chain of five records before this repository was born. They are **not**
entries on this repository's chain, which starts at its own seq 1 and does not link to them. They are listed so that a
reader who finds one of these subjects cited somewhere can find the record. The bytes are
[`.continuity/forensic.jsonl` lines 1-5](https://github.com/JerryBalmer1/claude.pwsh.image.builder/blob/5f711736e028f0078d8b32b732ec37cb224258be/.continuity/forensic.jsonl#L1-L5)
at `5f71173`, and the last `self` is that chain's tip.

| seq | ts | kind | subject | self |
|---|---|---|---|---|
| 1 | 2026-09-21T09:37:45Z | verification | `run-01-goal-update-06e738d` | `a476fdfdfd48f655af413d2057e8ff4f58966aa7f653f64963500f724706a140` |
| 2 | 2026-09-21T10:00:13Z | finding | `oneshot-2026-09-21-shapes-frozen` | `052d2db70d48a10111de147ffb105dada7eff07f725e57a0064bebfaa44c1035` |
| 3 | 2026-09-21T10:33:19Z | verification | `grok-fabricated-ship-report-confession-verified` | `8bfbf75adaf99911b32609c10636ec62f8cc831914aa6209ece54a229ae2d8fd` |
| 4 | 2026-09-21T10:33:20Z | finding | `grok-review-next-slice-would-reintroduce-version-drift` | `69988f482ff43949b648e686474c9fd8578dcc4eae5770ee149c2d23a346cf75` |
| 5 | 2026-09-21T10:33:20Z | finding | `root-cause-run-01-was-never-pushed` | `23e04995f13b29b729ee86eff2d1542e6a4e9739f83b68c95764ae7c31727761` |

## F97 - one commit, one machine, two input hashes: the key reads untracked files in the vendored Ledger

Numbered after core's F96, as Jerry directed. It isn't in the `I14-Fn` series.

- **What it did.** The two clones were both on this Windows machine, both had `core.autocrlf=true`, and both were at
  `8e309d7`. They gave different image input hashes. The long-lived working clone gave leash `44976343b9c1` and developer
  `7abc1bec4495`. A fresh clone made by `scripts/Bootstrap-Clean.ps1 -NoCache` under the system temp folder gave leash
  `656fc382a2ba` and developer `036f96fe6ebf`. The full hashes are in forensic seq 52. The content is the same, because
  both checkouts are the same commit with the same submodule gitlink, `db12239`.
- **Measured cause.** The entry list `Get-ImageInputHash` hashes (`build/Build.Helpers.psm1`) was printed from both
  clones and compared. Every line matches except the directory entry for
  `vendor/claude.agent.core/modules/ledger/python/`. That entry has 7 files in the working clone and 5 in the fresh one.
  The two extra files are `__pycache__/snake.cpython-310.pyc` and `__pycache__/validators.cpython-310.pyc`. They are
  untracked and ignored by core's `.gitignore:13`. A host CPython 3.10 wrote them at 2026-09-24T02:08:41Z, and nothing
  records which run did it.
  `Get-ChildItem -Recurse -File -Force` reads them, and nothing in `.dockerignore` excludes `__pycache__`.
- **Suspected causes ruled out by that measurement.** Line endings don't explain it: both clones are `autocrlf=true`,
  and every per-file hash that exists in both matches. Path components in the key don't explain it either: entries
  are context-relative, and the paths match line for line. File ordering doesn't: the shared entries appear in the
  same order. I14-F2's line-ending mechanism is real, but it isn't what separates these two.
- **Consequence.** The key is meant to identify what `COPY` sends, and here it did. That makes it likely, though
  unmeasured, that the working clone's images also shipped the two `.pyc` files under `/opt/leash/ledger/python/`.
  If so, a local image can carry bytes that no commit names.
- **Not fixed.** Jerry's direction for I14 is to record it. The candidate fixes are to exclude `__pycache__/` in
  `.dockerignore` and in the key, or to build from the index (as in I14-F2).

## I14-F2 - the image input hash reads working-tree bytes, so line endings change it

- **What it did.** In I14 PR 4 the same commit, `ac72829`, gave two input hashes for the leash image: `9707b49add1d`,
  then `60fb6a430292` after `git checkout 017d476` and back. No content changed. The checkout rewrote the new files with
  CRLF, because this clone has `core.autocrlf` on, and `Get-ImageInputHash` (`build/Build.Helpers.psm1`) hashes the bytes on
  disk, which `COPY` then ships.
- **Consequence.** An image built on this Windows clone and one built in CI (Linux, LF) from the same commit have different
  labels and different bytes. The suite passed on both, since pwsh reads either ending. But "same commit, same image" isn't
  true across machines.
- **Not fixed.** It's outside I14's list. The candidate fix is to hash and copy the index's bytes (`git ls-files --eol` or
  `git archive` as the build context), and that is a build change for its own PR.

## I14-F1 - the core submodule is not replaced by a release fetch

- **What stands.** Both images copy the Ledger module from `vendor/claude.agent.core`, a git submodule pinned in
  `config/vendor.json` and checked by `scripts/Bootstrap-Clean.ps1` and `tests/Bootstrap.Tests.ps1`. The packet names a
  release fetch as the alternative and records it as a finding, not an attempt.
- **What a fetch needs that core lacks.** Core has cut no release (`v0.2.1 is not cut`, `config/contracts.json`). There is
  no release asset to fetch, so nothing publishes a digest to verify a fetch against. Until both exist, the submodule's
  gitlink is the only content-addressed pin available.

## I13-F2 - automerge goes red after it merges into main and dispatches ci

- **What it did.** Automerge run 35964076759 merged the I13 promotion (#30, `8231263`), dispatched `ci` on `main`
  (run 35964101524, which completed green), and then exited 1 with *The property 'Dispatched' cannot be found on this
  object*. Nothing was lost, since the merge and the dispatch had both happened. The automerge run is red.
- **Cause.** `Invoke-CiDispatchOnMain` (`scripts/AutoMerge.Lib.ps1`) doesn't discard `gh workflow run`'s stdout. Real `gh`
  prints the created run's URL, which becomes part of the function's output, so the function returns `Object[]` and
  `$dispatch.Dispatched` throws under `Set-StrictMode -Version 3.0` (`scripts/Invoke-AutoMerge.ps1:201`). The tests shadow
  `gh` with a stub that prints nothing, so they couldn't see it. This was the first real dispatch.
- **Reproduced.** `gh` was shadowed locally. A silent stub gives `PSCustomObject`, `Dispatched=True`. A stub printing one URL line
  gives `Object[]` of 2 and the same exception.
- **Not fixed in I13.** It's outside the packet's list, and a fix reaches `main` only with the next promotion. The fix: `$null =`
  on the `gh` call, plus a test whose stub prints a line.
- **Caught now by.** `tests/CiOnMain.Tests.ps1`, *returns one clean object when gh workflow run prints a line*: red at
  `25113c6` with *Expected 1, but got 2*, green once `$null =` landed in the commit after it. The fix reaches the dispatching
  automerge only when `main` carries it, since automerge's `workflow_run` runs `main`'s copy.
- **Records.** Forensic chain seq 50, finding, `automerge-dispatch-output-leak`. The promotion is at seq 49.

## I13-F1 - 23b1db9 rewrote 658 lines of END_GOAL.md where one was meant

- **What it did.** Every `a` in `END_GOAL.md` became a space and every backtick became `j`, across the
  header and every section older than `23b1db9`. It rode through #17 to #20 because `Goal.Update` reads
  only the newest section. Found and repaired in I12 (#21, forensic seq 38, confession).
- **Cause.** An inline edit command held its one replacement as `@( @('<old>', '<new>') )`. `@()`
  unrolls the inner array, so the loop walked two strings and indexed characters, which gave
  `Replace('<backtick>', 'j')` and then `Replace('a', ' ')`.
- **Reproduced.** The exact entry and loop, on `23b1db9~1`'s blob `b017750`, give `23b1db9`'s blob
  `54901e2` byte for byte.
- **Caught now by.** `scripts/Edit-Text.ps1` refuses it at edit time: each old string must occur exactly
  once, and the declared line diff is checked before writing. `tests/ScriptedEdit.Tests.ps1` holds both
  the reproduction and the refusal. `tests/EndGoalIntegrity.Tests.ps1` (#21) catches damage to any
  section after the fact.
- **Sites in the tree using the pattern.** None. See the decision.
- **Records.** `DECISIONS.md` 2026-09-24, *23b1db9: a one-pair edit list unrolled into two one-character
  replacements*. Forensic chain seq 46, finding, `end-goal-23b1db9-root-cause`.
