# END_GOAL

The state of this repository, recorded by the run that changed it.

`Goal.Update` is the last task in the default chain and it fails the build
unless the newest run has a section here. See `AGENTS.md` for the required
fields. The `Tested` totals are cross-checked against
`output/incontainer.json`, so a green summary of a run that did not happen
fails the build rather than being believed.

---

## 2026-09-23 4290102 run-01

I12, after the promotion, `feature/ci-on-main-self-run`: the ci-on-main check from PR 3 was
self-referential, and this fixes it.

**Changed:**

- `tests/CiOnMain.Tests.ps1`: the live claim measures the packet's word, *completed*. Inside the ci run
  for main's tip, that run (`GITHUB_RUN_ID`) is the evidence. `AGENTS.md` wording follows.

**Tested:** passed=188 failed=0 skipped=6 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. Host: the live check passes and reports `bc7b64c`, 1 completed ci run,
conclusion failure.

**Failed:** none in this tree. **On main:** `bc7b64c`'s only ci run, 35957396113 (dispatched by hand,
by claude), failed on the defective check this fixes. `main` keeps that copy of the test until the
next promotion.

**Missing:**

- The in-run branch runs only on a runner, so its first real exercise is the next promotion's
  automerge dispatch.
- `bc7b64c` has no successful ci run, and none is manufactured.

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** confession at seq 42 (`ci-on-main-test-self-referential`). `Goal.Update` appends
its own `verification` record.

## 2026-09-23 6ab3298 run-01

I12 PR 5, `feature/ledger-receipt-caller`: `src/LedgerReceipt.ps1` is deleted. It shipped in both
images and nothing called it.

**Changed:**

- `src/LedgerReceipt.ps1` and its behavioural test deleted. `AGENTS.md` and `END_GOAL.md` were checked
  first: neither names it as a required receipt writer. The file sweep in `tests/LedgerPath.Tests.ps1`
  stays.
- `tests/ShippedScripts.Tests.ps1`: every script under `src/` needs a caller outside `tests/`. It was red
  before the deletion, on this file alone.
- Dockerfiles unchanged. No line copied this file by name; `COPY src/` stays because
  `src/PlanValidator.ps1` ships through it. Measured after the build: `/opt/leash/src/` holds only
  `PlanValidator.ps1` in both images.
- `DECISIONS.md` entry.

**Tested:** passed=187 failed=0 skipped=6 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
wall 34.01s, `unjustified_skips` empty. Both images built.

**Failed:** none.

**Missing:**

- `tests/run.ps1` still exits 0 on a discovery failure and still binds a second positional argument to
  `-Evidence` (recorded in the repair section below; not in I12's scope).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** decision before any edit at seq 40 (`ledger-receipt-deleted`), naming the one false
premise. `Goal.Update` appends its own `verification` record.

## 2026-09-23 d4632d1 run-01

I12, unplanned repair before PR 5, `feature/end-goal-repair`: this file had been corrupted by
`23b1db9`, and it is rebuilt.

**Changed:**

- `END_GOAL.md` restored. `23b1db9` (I12 PR 1) rewrote 658 older lines - every `a` gone, every backtick
  turned into `j` - where one line was meant to change. The header and every older section now come
  from `23b1db9^`, with that one intended line re-applied. The four sections written since are kept
  as they were.
- `tests/EndGoalIntegrity.Tests.ps1` checks the required fields in **every** run section, not only
  the newest, which is all `Goal.Update` reads. It was red before the repair (4 passed, 10 failed).

**Tested:** passed=185 failed=0 skipped=6 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
wall 33.01s, `unjustified_skips` empty. (184 before this section existed: the integrity test checks each section, this one included.)

**Failed:** none.

**Missing:**

- How `23b1db9` came to carry the damage is not established. The file had changed on disk between the
  scripted email edit and the next edit. This record says that much and no more.
- `tests/run.ps1` exits 0 when a test file fails discovery, and a second positional argument binds
  to `-Evidence`, which force-overwrites that path with a transcript. Both were met during this repair.
  Both are recorded and not fixed here.

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** confession at seq 38 (`end-goal-corrupted-by-23b1db9`). `Goal.Update` appends its
own `verification` record.

## 2026-09-23 c7b2dee run-01

I12 PR 4, `feature/docker-tests-in-ci`: the 21 Docker-tagged tests run in CI, and the in-container
suite's wall time is shown.

**Changed:**

- `scripts/ci/Invoke-Tests.ps1` excludes no tag. The `pester` required check on the ubuntu runner
  builds both images and runs the Docker-tagged tests. A hard gate fails the check on any NotRun.
- `Test.InContainer` and the `incontainer` job print `wall=<s>s`, from the `duration_s` the in-container
  run already wrote.
- `tests/CiCoverage.Tests.ps1`: red before the fix (0 passed, 4 failed), green after.

**Tested:** passed=169 failed=0 skipped=6 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. **In-container suite wall time: 33.5s** (`Test.InContainer` at `c7b2dee`;
the task took 39.3s with container start). `scripts/ci/Invoke-Tests.ps1` locally, as CI runs it:
total=196 passed=193 failed=0 skipped=3 **notrun=0**, 90s. The Docker-tagged tests needed no new skip.

**Failed:** none.

**Missing:**

- The Docker-tagged tests still cannot run inside the image: there is no docker daemon there. They run
  in the `pester` check instead, which is where the packet asked for them.
- `src/LedgerReceipt.ps1` still ships with no caller (I12 PR 5).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** decision before any edit at seq 36 (`docker-tests-in-ci`). `Goal.Update` appends its
own `verification` record.

## 2026-09-23 f470895 run-01

I12 PR 3, `feature/ci-on-main`: after a merge into main, automerge dispatches `ci.yml` on main.

**Changed:**

- `Invoke-CiDispatchOnMain` in `scripts/AutoMerge.Lib.ps1`, called by `Invoke-AutoMerge.ps1` after the
  merge. `automerge.yml` gets `actions: write`. `ci.yml` gets `workflow_dispatch` and `actions: read`.
- `AGENTS.md` claim: the commit at main's tip has a completed, successful ci run.
- `tests/CiOnMain.Tests.ps1`: the dispatch decision with `gh` shadowed, the checker on fixed commits
  (`6b8943a` has 0 ci runs, measured, kept as the red case; `74c1db2` has one), and the live claim.
  Red before the fix: 4 failed.

**Tested:** passed=165 failed=0 skipped=6 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. The three new skips are `no-gh-cli`.

**Failed:** none.

**Missing:**

- **The live claim cannot run yet.** Automerge's `workflow_run` runs `main`'s copy of itself, so the
  promotion that brings the dispatch to `main` is merged by the pre-dispatch copy. The packet's
  "confirm PR 3's dispatch produced a ci run on the new main tip" rests on a false premise for that
  promotion. The first automerge dispatch comes one promotion later.
- Automerged merges into `develop` get no push CI either. Their trees are the checked pull request
  heads. This is recorded at seq 34 and not changed.
- The Docker-tagged tests still run nowhere in CI (I12 PR 4).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** decision before any edit at seq 34 (`ci-on-main`), naming the false premise.
`Goal.Update` appends its own `verification` record.

## 2026-09-23 24e8812 run-01

I12 PR 2, `feature/merge-settings`: the repository enforces merge commits only, and a test reads that live.

**Changed:**

- GitHub setting, by `gh repo edit --enable-squash-merge=false --enable-rebase-merge=false` after the
  test was red in CI: squash `true` -> `false`, rebase `true` -> `false`, merge commit `true`. Branch
  protection was not attempted.
- `AGENTS.md` claim, and `tests/MergeSettings.Tests.ps1` reading the three settings through
  `gh api graphql`. No answer is a failure. Without `gh` - inside the images - it skips as
  `SkipWhen:no-gh-cli`. `ci.yml` gives the `pester` step `GH_TOKEN` from the workflow's `GITHUB_TOKEN`.
- Red before the change: host, and CI run 35953595780 (`pester`: squash reported `true`).

**Tested:** passed=161 failed=0 skipped=3 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. The third skip is `no-gh-cli`, justified on the test object.

**Failed:** none.

**Missing:**

- The Docker-tagged tests still run nowhere in CI (I12 PR 4).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** decision before the change at seq 32 (`merge-commits-only`). `Goal.Update` appends
its own `verification` record.

## 2026-09-23 23b1db9 run-01

I12 PR 1, `feature/public-hygiene`: the repository is public, so it now carries a licence and keeps
private names and addresses out of tracked files.

**Changed:**

- `LICENSE`, MIT, JerryBalmer1, 2026, stated in one line of `README.md`.
- Scan of every tracked file at `e195e49`: 0 local user paths, 0 tokens or keys, 1 email address
  (the line below at `:291` in the 2026-09-23 0c0f714 section), and 45 occurrences of the private
  origin repository's name, 35 of them in live files. All live hits are edited.
- `tests/PublicHygiene.Tests.ps1` fails on any of the four in a tracked file outside `.continuity/`.
  Red at `e195e49`: host, and CI run 35952853389 (`pester` 2 failed, on email and name).
- `DECISIONS.md` created. It lists the forensic records that carry a hit and are not edited.

**Tested:** passed=161 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. Five tests added.

**Failed:** none.

**Missing:**

- Personal author addresses in git commit metadata and in older blobs of this file. They can only be
  cleared by a history rewrite, which is not done here and never is. See `DECISIONS.md`.
- The Docker-tagged tests still run nowhere in CI (I12 PR 4).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(receipts at `output/ledger/ledger.jsonl`; `Goal.Update` checks its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by
`Bootstrap`.

**Forensic chain:** decision before any edit at seq 29 (`public-hygiene`), the finding for
records left unedited at seq 30 (`public-hygiene-records-not-edited`). `Goal.Update` appends its
own `verification` record.

## 2026-09-23 439e2c4 run-01

I11 PR B, `feature/drop-directory-guard`: `tests/run.ps1` no longer refuses on its folder name. The
claude.agent.tools T0 inspector found the guard.

**Changed:**

- **The guard is gone.** `tests/run.ps1` threw `NOT IN CLAUDE.AGENT.IMAGES` unless the caller's git
  toplevel ended in this repository's name. The root is now the folder the script lives in, as in
  claude.agent.tools' copy.
- **Pester is pinned from `config/repo.json`** (6.1.0), not the 5.x range. The images ship only
  6.1.0, so this runner had never been able to run in the container on either count.
- **`tests/RunnerFolder.Tests.ps1`.** It clones the committed HEAD into a folder named with a random
  guid, then runs the clone's runner on a probe test from inside the clone. It was red at `3921c4b`,
  on the host and in CI run 35950457428 (`pester` and `incontainer`, each refusing with
  `NOT IN CLAUDE.AGENT.IMAGES`), and green from `439e2c4`.

**Tested:** passed=156 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. Host `tests/run.ps1`, now on Pester 6.1.0: 177 passed, 0 failed, 2
skipped. Two tests added.

**Failed:** none.

**Missing:**

- The 21 Docker-tagged tests still run nowhere in CI; in-container timing is unmeasured here. Both are
  out of scope for I11.
- `src/LedgerReceipt.ps1` still has no caller (see the section below).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `d4e578ba8988229c2738b4ac8f3a3e2478f622ca8a745c0712dae4e29b11b3e0`
(receipts at `output/ledger/ledger.jsonl`. It moves on every `Test.InContainer`, so
`Goal.Update` checks its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by
`Bootstrap`.

**Forensic chain:** decision recorded BEFORE any edit at seq 26, `kind=decision`,
`subject=drop-directory-guard`, `prev 2cd6ac5d`, `self 9933bcf7`. It places the Pester import at
`:31`; it was at `:33`, corrected in `439e2c4`'s message, record unchanged. `Goal.Update` appends its
own `verification` record.

## 2026-09-23 6232e03 run-01

I11 PR A, `feature/ledger-receipt-path`: `src/LedgerReceipt.ps1` finds claude.agent.core's ledger
module, found by the claude.agent.tools T0 inspector.

**Changed:**

- **`Invoke-LedgerBootVerify` looks where the module is.** Candidates are
  `/opt/leash/ledger/Ledger.psd1`, where both Dockerfiles COPY core's `modules/ledger/ledger.psd1`,
  and `vendor/claude.agent.core/modules/ledger/ledger.psd1` on the host. The two entries naming the
  retired ledger repository's vendor path are gone. That repository was never a submodule here:
  `.gitmodules` declares `vendor/claude.agent.core` alone.
- **`Join-Path (if ...)` became `Join-Path $(if ...)`.** In PowerShell 7 the first form is a runtime
  error. The packet did not name it; it sits on the line the path fix makes reachable, and PR #13's
  first CI run showed it failing inside the image.
- **`tests/LedgerPath.Tests.ps1`.** A sweep for the old repository name in any form across `src/`,
  `hooks/`, `scripts/`, `entrypoint.ps1` and both Dockerfiles, plus a Ledger-tagged test that
  Invoke-LedgerBootVerify answers from core's `Get-LedgerVerify` on a real chain. Both were red at
  `050e3d8`: host 0 passed, 2 failed; CI run 35949377012 red on `pester` and `incontainer` with
  exactly these two tests.

**Tested:** passed=154 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. Host `tests/run.ps1`: 175 passed, 0 failed, 2 skipped. Two tests added.
The `Invoke-Build Test.InContainer` log has 415 lines, and none contains the old repository name.

**Failed:** none.

**Missing:**

- `src/LedgerReceipt.ps1` has no caller: nothing dot-sources it or calls `Invoke-LedgerBootVerify`,
  and both images still COPY it through `src/`. Whether it should be wired or deleted is not decided
  here.
- The 21 Docker-tagged tests still run nowhere in CI; in-container timing is unmeasured here. Both are
  out of scope for I11 and belong to their own packet.

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `d4e578ba8988229c2738b4ac8f3a3e2478f622ca8a745c0712dae4e29b11b3e0`
(receipts at `output/ledger/ledger.jsonl`. It moves on every `Test.InContainer`, so
`Goal.Update` checks its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by
`Bootstrap`.

**Forensic chain:** decision recorded BEFORE any edit at seq 24, `kind=decision`,
`subject=ledger-receipt-path-to-core`, `prev f83f3a16`, `self 69ad2087`. It places the
if-in-parentheses at `:105`; it was at `:109`, corrected in `6232e03`'s message, record unchanged.
`Goal.Update` appends its own `verification` record.

## 2026-09-23 67cbfd1 run-01

I10 PR B, `feature/ci-incontainer`: CI runs the suite inside the image, and FINDING-M17 is
retired with the measurement that killed it.

**Changed:**

- **A required `incontainer` job.** It builds both images on the runner and runs
  `Invoke-Build Test.InContainer` through `scripts/ci/Invoke-InContainer.ps1`, uploading
  `output/incontainer.json` as an artifact. InvokeBuild pinned at `tooling.invokebuild`
  5.14.23. The runner measured 1m57s for the whole job, with images built cold in 67.4s -
  under the 10-minute threshold fixed at seq 21 before measuring - so it gates pull requests
  and is in `required_checks`. `POLICY.md` and the PR template regenerated.
- **FINDING-M17 retired.** core is public; PR #9's `pester` job checked the submodule out
  with no token and ran all 43 Ledger-tagged tests. The entry itself lives only in
  `claude.pwsh.image.builder`, so it is retired on this chain at seq 21, not copied here.
- **`scripts/ci/Invoke-Tests.ps1`: a missing Ledger now fails the check** instead of
  excluding the tag. The exclusion existed only for the PAT nobody had; without that reason
  it was an unguarded green.
- **Three old END_GOAL records annotated, not rewritten** - dated notes under the sentences
  that asserted M17's private premise, original words kept.
- **One runner-only defect found and fixed:** `Invoke-Build -Result ib` failed on the runner
  with "variable has been optimized" after passing locally; `-Result` now takes a hashtable.

**Tested:** passed=152 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid
1001, total 175, NotRun 21 (all Docker-tagged), `unjustified_skips` empty. The same numbers
on the runner, inside the image, in the `incontainer` job. Runner `pester`: 152 / 0 / 2,
NotRun 21, Docker only. No test added or removed this run.

**Failed:** none.

**Missing:**

- The Docker-tagged tests (21) still run nowhere in CI. There is no docker daemon inside the
  image, and the runner-host `pester` job excludes them by design (M13). `docs/plans/2026-09-21-cleanup/FINDINGS.md`,
  which M13 cites, is not in this tree.
- `incontainer` is required from the NEXT pull request into develop: automerge reads
  `required_checks` from the base branch.

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `4cd5b9348323773a72b5a949873bf3cc021f041ee46bef15ad1d563e2939e9d3`
(receipts at `output/ledger/ledger.jsonl`. It moves on every `Test.InContainer`, so
`Goal.Update` checks its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by
`Bootstrap`.

**Forensic chain:** decision recorded BEFORE any edit at seq 21, `kind=decision`,
`subject=ci-incontainer-m17-retired`, `prev c95ad544`, `self 6334f210`. `Goal.Update`
appends its own `verification` record.

**Falsified in the place it guards.** Scratch commit `90dfc59` put one untagged `-Skip` on a
test inside a Ledger-tagged Describe. Run 35943528887 went red on `pester` and on
`incontainer`, each naming exactly that test. `67cbfd1` removed it with a new commit. Before
PR #9 the same line was excluded on the runner and would have been tolerated green.

## 2026-09-23 ffa9341 run-01

I10 PR A, `feature/stale-premises`: five stale premises, one commit each, one decision
record first.

**Changed:**

- **The repository calls itself `claude.agent.images`.** `config/repo.json:3`,
  `schemas/repo.schema.json:3`, `.build.ps1:5`, `build/Build.Helpers.psm1:5`,
  `scripts/env.ps1:75`, `docs/GITFLOW.md:1`, `FLOW.md:35`. `docs/POLICY.md:9` is the
  rendered `repo` field, so it was regenerated by `scripts/Generate-Policy.ps1`, not edited.
  `scripts/env.ps1:67` describes the OLD guard and stays a sentence about it.
- **The `pester` check takes the submodule.** `ci.yml:60-80` named
  `vendor/claude.build.ledger` as a private submodule needing a PAT. The submodule is
  `vendor/claude.agent.core` and core is public. There was no token plumbing to drop - no
  `token:` or `submodules:` key in any of the three workflows. The comment is rewritten and
  `submodules: recursive` added, so the 43 Ledger-tagged tests run in that required check
  for the first time.
- **`docs/plans/BACKLOG.md`: 04 is no longer blocked on Pro.** The 403 was private-only;
  the repository is public; 404 means available and unset; protection on `main` is on by
  decision. The Pro row is checked off with the reason, not deleted.
- **`scripts/ci/Test-PushGuard.ps1:19-25`**, comment only: the protection premise rewritten
  to what was measured - `main` protected without admin enforcement, `develop` 404
  unprotected, rulesets `[]`. The tripwire's gap is narrower, not closed.
- **One test, two hooks, recorded as a recurrence.** A one-element JSON array piped through
  `hooks/sentinel.ps1` (fails closed, exit 2) and `.claude/hooks/Deny-Heredoc.ps1` (fails
  open, exit 0), with a control proving the unwrapped object is denied. The prior packet's
  "both now carry `-NoEnumerate`" was false: only Deny-Heredoc does; the sentinel defends
  with a raw-text check.

**Tested:** passed=152 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0,
uid 1001, total 175, NotRun 21 (all Docker-tagged), `unjustified_skips` empty. Host
`Test.Unit`: passed=173 failed=0 skipped=2. Host `tests/run.ps1`: 173 passed, 0 failed,
2 skipped, 0 NotRun - baseline was 172, and the one added test is the whole delta.
`scripts/ci/Invoke-Tests.ps1` locally: total=175 passed=152 skipped=2 NotRun=21, PASS -
what the runner now runs, Ledger included. The new test was falsified both ways: without
`-NoEnumerate` it goes red on a 330-byte deny; without the StartsWith check it goes red on
stderr, while the exit code STAYED 2 for an unrelated reason.

**Failed:** none.

**Missing:**

- FINDING-M17, the PAT premise, is still asserted in `scripts/ci/Invoke-Tests.ps1:71-96`
  and `:128`. That is PR B.
- CI still does not run the in-container suite. That is PR B.
- `docs/plans/2026-09-21-cleanup/FINDINGS.md`, cited for M13 and M17, is not in this tree.
  It exists only in `claude.pwsh.image.builder`, left behind at birth.

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `537a1e40fb567f41aeca05857591afa26975c7698f0155de5e4041519a86b8c3`
(receipts at `output/ledger/ledger.jsonl`. It moves on every `Test.InContainer`, so
`Goal.Update` checks its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by
`Bootstrap`.

**Forensic chain:** decision recorded BEFORE any edit at seq 19, `kind=decision`,
`subject=stale-premises-five-items`, `prev 941a794b`, `self eff4c8a9`. `Goal.Update`
appends its own `verification` record.

## 2026-09-23 0c0f714 run-01

The repository is public by decision. The rule that forbade it is retired, not broken.

**Changed:**

- **`AGENTS.md:56` stops being a prohibition and becomes the fact.** "Never make this
  repo public" held from birth; the repository is public - GitHub API `private: False`
  - and Jerry has decided it stays that way. The Do-not bullet now states the fact, and
  says what replaces the rule: nothing enters this tree that a stranger should not read.
  Core's `docs/plans/2026-09-22-public-release/` is NAMED as the authority on what stays
  out of a public tree, not copied - this repository does not vendor that plan.
- **Disagreement table row 8** records the prior rule, the date it stopped holding, and
  the sequence that is the actual finding: the rule was being broken while `state.ps1`
  refused to run and therefore could not say so; it became sayable the moment that guard
  was fixed (seq 12, item 5); it was retired one packet later once someone decided.
- **`scripts/state.ps1` reports visibility instead of judging it.** The `private:` line
  stays; the `WARNING: repository is PUBLIC - it must not be` is gone. A report that
  judges by a retired rule is worse than one that does not judge, because a reader cannot
  tell which of its warnings still mean anything. The merge-commit warning beside it is
  untouched - that rule is live.
- **The promotion of `994adf8` finally has a forensic record**, at seq 17, carrying all
  three DoD clause measurements as taken at `ac6f167`. PR #7 landed without one.
- **A PreToolUse hook that refuses heredocs.** `.claude/settings.json` plus
  `.claude/hooks/Deny-Heredoc.ps1`: a Bash call whose command contains `<<` is denied with
  "PowerShell only - see AGENTS.md". Exit 0 with a decision body, not exit 2 - the shape
  `hooks/sentinel.ps1` already had to be repaired into. Fails open on a malformed payload;
  this guards the hands of an agent trying to comply, not an adversary.

**Tested:** passed=151 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0,
uid 1001, total 174, `unjustified_skips` empty. Host `Test.Unit`: passed=172 failed=0
skipped=2 NotRun=0 Inconclusive=0. No test was added or removed: **zero tests asserted
the repository was private**, measured before the rule was touched, so retiring it
removed nothing. `requires-header` 39 files checked, 0 missing, with the new hook script
tracked.

**Failed:** none.

**Missing:**

- **The hook did not arm in the session that wrote it.** Claude Code snapshots hooks at
  session start and watches only directories that already held a settings file; this
  repository had no `.claude/` at all. A heredoc pushed through the Bash tool minutes
  after the file was written ran normally. The script itself was falsified directly -
  five payloads, five correct verdicts - so this is a timing property, not a broken
  shape. Open `/hooks` once, or start a new session.
- **Commit metadata carries a personal email and cannot be fixed.** `git log --all` shows
  a personal gmail address (removed from this line 2026-09-24, I12 PR 1; it remains in git history) as the author of every human commit and the committer of every
  commit in the repository, and it is now world-readable. No history rewrite - not now,
  not ever. `git config user.email` in this clone is still that address, so every future
  commit adds it again; stopping the forward leak is a one-line identity change plus
  GitHub's keep-my-email-private setting, and both are Jerry's to make.
- **Branch protection is no longer 403 on this repository.** `docs/plans/BACKLOG.md:45-50`
  blocks backlog item 04 on a GitHub Pro upgrade, measured 2026-09-21 as 403 "Upgrade to
  GitHub Pro **or make this repository public**". Re-probed today: `/rulesets` returns
  `[]` exit 0 and `/branches/main/protection` returns 404 "Branch not protected". The
  Free-tier limit applies to private repositories only. That also makes the premise at
  `scripts/ci/Test-PushGuard.ps1:19-25` stale for this repository. Nothing is configured
  here: turning protection on changes how every merge lands and is Jerry's call.
- **`claude.agent.core` is itself public**, measured. FINDING-M17 says CI cannot clone the
  submodule because core is private and needs a PAT passed to `actions/checkout` as
  `token:`. That premise is dead: a public submodule clones without a secret, so the 43
  Ledger-tagged tests could run in CI. The M17 PAT was explicitly out of scope for this
  run, so it is measured and reported rather than acted on. Separately,
  `.github/workflows/ci.yml:60-80` still names `vendor/claude.build.ledger` and
  `claude.build.ledger` as the private submodule; the submodule is `vendor/claude.agent.core`.
  Doubly stale, not edited here.
  *Annotated 2026-09-23, original words kept above: acted on. PR #9 rewrote the `ci.yml`
  comment and added `submodules: recursive` (seq 19); its pester job ran the 43 tests with
  no token. M17 is retired at seq 21.*
- `config/repo.json -> repo` and `schemas/repo.schema.json:3` both still name
  `claude.pwsh.image.builder`.
- The README still carries pre-birth wreckage: a `Test.FailFirst` row for a deleted task,
  a `docker run` example passing `LEDGER_HOOK_ARM=1` that the law forbids, and a
  `.agents/BREADCRUMBS.md` that never existed in this repository.

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `e35e9af6c478b126373491953d885f560b5e30fe473167e67a1e97a82d0a0530`
(receipts at `output/ledger/ledger.jsonl`. It moves on every `Test.InContainer`, so
`Goal.Update` checks its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by
`Bootstrap`.

**Forensic chain:** decision recorded BEFORE any edit at seq 16, `kind=decision`,
`subject=repo-public-by-decision`, `prev 8ecffe0c`, `self ba6defab`. The overdue promotion
record follows at seq 17, `kind=verification`,
`subject=promotion-develop-to-main-994adf8`. `Goal.Update` appends its own, so this run
adds three records.

**Exposure, measured because the tree is visible.** Live tree: **zero** local paths and
**zero** email addresses, `git grep` over everything but `vendor/`. The only `C:` strings
are the placeholder `C:\...` illustrations in comments at `tests/Env.Tests.ps1:25` and
`tests/TestHelpers.psm1:213`. History patch content, `git log --all -p`: **zero** matches.
The exposure that does exist is commit metadata, listed under Missing above, and it is not
fixable without a rewrite this repository will not do.

## 2026-09-23 531b2e0 run-01

I7: the skip-justification gate becomes a required check, on the host half.

**Changed:**

- **`scripts/ci/Invoke-Tests.ps1` now runs `Assert-SuiteClean`.** The `pester`
  required check exited 1 on exactly two conditions - zero tests, and a failed test.
  An unjustified skip went green there and red under `Invoke-Build Test.Unit`, so CI
  passed what Full fails.
- **`Assert-SuiteClean` moved to `build/Build.Helpers.psm1` and is exported.** It had
  to move: it called `Write-Build`, an Invoke-Build command, so no plain pwsh script
  could call it where it lived. That module already documents itself as
  Invoke-Build-free, which is why the container imports it off the bind mount.
  `Write-Build` became `Write-Host` with the same colours. It is the SAME function
  both callers run, not a port.
- **One behaviour change, parameterised rather than forked: `-ExcludeTag`.** Pester
  reports a tag-excluded test as `NotRun`, which is not a skip. A `NotRun` whose
  inherited tags include one of the excluded values is tolerated; every other
  `NotRun`, and every `Inconclusive`, stays unjustified. `Test.Unit` passes nothing
  and excludes nothing, so its verdict is unchanged. This is the rule
  `build/InContainer.Test.ps1:159-164` already applies, so the host and container
  gates now differ on `NotRun` by argument instead of by accident.
- **`config/repo.json -> required_checks` untouched.** `pester` is already in it;
  this changes what that check measures, not which checks exist, so
  `generated-match-config` stays green without editing the config.

**Tested:** passed=151 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0,
uid 1001, total 174, `unjustified_skips` empty. Host `Test.Unit`: passed=172 failed=0
skipped=2 NotRun=0 Inconclusive=0, reporting both skips as
`no-exempt-commit-in-range` exactly as before the move. `scripts/ci/Invoke-Tests.ps1`
run locally: exit 0, total=174 passed=151 skipped=2 NotRun=21, the same
justified/unjustified split `output/incontainer.json` records. No test was added or
removed this run.

**Failed:** none.

**Missing:**

- **CI still cannot run the in-container suite.** `vendor/claude.agent.core` is a
  private submodule and `actions/checkout` needs a PAT passed as `token:` -
  FINDING-M17, Jerry to create. All **43** Ledger-tagged tests stay `NotRun` on the
  runner, tolerated by the very `-ExcludeTag` this run adds. The host gate stops CI
  passing what Full fails; it does not make CI prove what Full proves. Floor, not
  ceiling.
  *Annotated 2026-09-23, original words kept above: the private premise was false by then -
  core was public. No PAT was ever needed. The Ledger-tagged tests have run in the pester
  check since PR #9, and an absent submodule now fails it rather than excluding them. M17 is
  retired at seq 21.*
- The 21 Docker-tagged tests are still excluded in CI by design (FINDING-M13), so a
  pull request that breaks the Dockerfile still goes green there.
- `build/InContainer.Test.ps1` still implements the gate inline rather than calling
  the shared function. Deliberate: it writes `output/incontainer.json` and its
  reporting medium differs. Two implementations of one shared rule, now with two
  callers on the host side.
- `config/repo.json -> repo` still reads `JerryBalmer1/claude.pwsh.image.builder`.
- **The repository is PUBLIC**, against `AGENTS.md`. `state.ps1` warns on every run.
- The README still carries pre-birth wreckage - a `Test.FailFirst` row, a
  `LEDGER_HOOK_ARM=1` example the law forbids, a `.agents/BREADCRUMBS.md` that does
  not exist.

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code
  semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not
  relisted.

**Ledger head hash:** `3951b581642acf5de6c9d81d818e91323a212941b686b72e93f27b0fca60ded6`
(receipts at `output/ledger/ledger.jsonl`. It moves on every `Test.InContainer`, so
`Goal.Update` checks its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified
by `Bootstrap`.

**Forensic chain:** decision recorded BEFORE the edit at seq 14, `kind=decision`,
`subject=ci-pester-runs-assert-suite-clean`, `prev 28e12c75`, `self d531447d`.
`Goal.Update` appends its own `verification` record, so this run adds two.

**Falsified in the place it guards, not only on this desk.** A scratch commit
carrying one `-Skip` with no tag was pushed to `feature/ci-suite-clean` and drove the
`pester` check RED on the runner; the run URL is in the pull request body. A second
commit removed it - not a force-push, `AGENTS.md` forbids one - and the check went
green. Locally the same probe gave `scripts/ci/Invoke-Tests.ps1` exit 1 naming the
test, with the two real skips still reported as justified.

## 2026-09-23 d6c54cb run-01

Six governance items every packet since #1 had walked past, decided rather than
deferred again. One decision record, seq 12, covering all six.

**Changed:**

- **`docs/plans/ACTIVE.md` retired; the stale-plan STOP reinstated with a reading.**
  The file had been in the tree since the birth commit `f1aeb60`, naming
  `feature/env-local` from two features ago. `AGENTS.md` row 2 suspended the STOP
  because "ACTIVE.md does not exist here" - false from birth. The row now reads: no
  `ACTIVE.md` means no active plan, a legal state, and the STOP fires only when the
  file exists and names a branch other than the current one. It names the four pull
  requests that walked past it - #1 `b03aa76`, #2 `66a78d6`, #3 `3e47c9e`,
  #4 `bcd8fa4`. `scripts/state.ps1` printed the opposite reading and is corrected;
  `AGENTS.md:24-31` and `FLOW.md:187-188` are deliberately not edited, because the
  disagreement table is where a reading lives.
- **The frozen-plans justification retired; the rule in force given a test.**
  `tests/Repo.Tests.ps1` excluded `docs/plans/` as FROZEN RECORDS "covered by a
  HASHES.txt". No HASHES.txt is tracked in this repository at all; the only one
  reachable is in `vendor/claude.agent.core` at pin `a68664e` and covers nine
  artefacts belonging to core. Nor are plans frozen here - `e221ddb` edited four
  plan sites. The rule actually in force is now asserted rather than asserted-about:
  a plan may be annotated in past tense with a date, original measurements
  preserved. Eight recorded measurements are pinned; a changed number fails, a dated
  annotation does not. The `^docs/plans/` exclusion itself stays, because
  `ASSESSMENT.md:406` carries the pre-move path.
- **The D7 `Add-LedgerReceipt` objection: open in core, closed in images.** Measured
  at pin `a68664e6b9938773478d967348b590f487fe2443`: the name exists in neither tree
  and core exports the raw `Add-LedgerRecord` at `ledger.psd1:9`. A wrapper over a
  Ledger export is Ledger API; this repository consumes core and adds none, so the
  objection stops reading as an unmet obligation of this tree. No wrapper written,
  core untouched.
- **Clause (b) of promotion written into the README.** It is the exit code of
  `Invoke-Build Test.InContainer`, not the suite tally inside it: at `3e47c9e` the
  container reported `passed=150 failed=0 skipped=2` and the task still exited 1.
  The README had no definition of done at all, so the section was created to hold
  the rule.
- **`scripts/state.ps1` runs here.** The guard pinned the origin to
  `claude.pwsh.image.builder` and exited 1 in this repository, which is why every
  state block since birth was hand-assembled. No name list replaces it: the origin
  is read and printed, and what is asserted is that the work tree being reported on
  is the work tree this copy of the script lives in. Falsified from another clone:
  exit 1, both paths named.
- **`scripts/ci/Test-PushGuard.ps1:44`** named `config/trailer-grandfather.txt`; the
  file is at `.continuity/trailer-grandfather.txt`. Comment only. The provenance
  header three lines up claimed byte-identical-at-copy-time, which that edit
  falsifies, so it moves to adapted=YES and says what the difference is.

**Tested:** passed=151 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0,
uid 1001, total 174, 34.76s, `unjustified_skips` empty and both real skips reported
as `no-exempt-commit-in-range`. Host `Test.Unit`: passed=172 failed=0 skipped=2
NotRun=0 Inconclusive=0. Host `tests/run.ps1` (Pester 5.7.1): 172 passed, 0 failed,
2 skipped. One test added this run - the plan-annotation rule - which is the whole
of the 171 to 172 and 150 to 151 movement.

**Failed:** none.

**Missing:**

- The skip-justification gate is still not in the CI required set. That is I7, the
  next pull request on this branch line, and `config/repo.json -> required_checks`
  is untouched here.
- CI still cannot run the in-container suite. `vendor/claude.agent.core` is a private
  submodule and `actions/checkout` needs a PAT passed as `token:` - FINDING-M17,
  Jerry to create. The Ledger-tagged tests stay `NotRun` on the runner.
  *Annotated 2026-09-23, original words kept above: the private premise was false - core
  is public and needs no PAT. M17 is retired at seq 21; see the newer sections.*
- `config/repo.json -> repo` still reads `JerryBalmer1/claude.pwsh.image.builder`.
  Stale in the same way `state.ps1` was, and not fixed here: it is an input to the
  `generated-match-config` check and changing it is its own decision. Listed.
- **The repository is PUBLIC.** `AGENTS.md` says "Never make this repo public".
  `state.ps1` prints the warning on every run now that it runs at all. Not an agent
  decision to reverse; listed loudly.
- The README still carries pre-birth wreckage the clause-(b) section sits beside: a
  `Test.FailFirst` row for a task that was deleted, a `docker run` example passing
  `LEDGER_HOOK_ARM=1` that `AGENTS.md` forbids (disagreement row 4), and a
  `.agents/BREADCRUMBS.md` that does not exist. Row 4 already says the README is
  wrong; this run added a section rather than rebuilding the file.

**Blockers:**

- **No signing key.** Not touched. `actor` and `LEDGER_PRINCIPAL` are
  operator-asserted and are places to be caught lying, not signatures.
- **Command-hook timeout fails open.** Not touched. The 15s PreToolUse timeout is
  Claude Code semantics; a sentinel that hangs is a sentinel that is not consulted.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not
  relisted; see the 2026-09-21 section for its history.

**Ledger head hash:** `841c9dd4a2968a4ae7851bdf74a7c0c083ffe174a5fe9fda00728a685fec8742`
(receipts at `output/ledger/ledger.jsonl`, written by the sentinel baked into the
image. It moves on every `Test.InContainer`, so `Goal.Update` checks its shape, not
its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged by this run and
re-verified by `Bootstrap`.

**Forensic chain:** the decision was recorded BEFORE any edit, at seq 12,
`kind=decision`, `subject=tidy-before-promotion-six-items`, `prev 41aafeb2`,
`self a0a3ce9e`. `Goal.Update` appends its own `verification` record at the end of
this run, so this run adds two records.

**Falsified, not asserted.** The new plan-annotation test was driven both ways with
scratch edits to `docs/plans/2026-09-21-oneshot/END_GOAL.DRAFT.md`, each reverted and
the tree verified clean: `passed=109` rewritten to `passed=110` gave exit 1 naming the
file and the value, and a dated past-tense annotation appended to the same file gave
exit 0. The rewritten `state.ps1` guard was driven red from another clone.

## 2026-09-23 5d48942 run-01

The skip-justification gate and the conditional skip stop colliding.

**Changed:**

- **A second justified form on the gate.** `build/InContainer.Test.ps1` and
  `Assert-SuiteClean` in `build/tasks/Test.build.ps1` tolerated a skipped test
  only if it carried a `BLOCKER-n` tag. They now also accept
  `SkipWhen:<kebab-reason>`, matched by
  `^SkipWhen:(?<reason>[a-z0-9]+(-[a-z0-9]+)*)$`. Both forms are read off the
  Pester test object — its own tags plus every parent block's — so the
  justification is a thing the gate measures rather than a comment nobody
  executes.
- **Why not `BLOCKER-n`.** A blocker is a defect someone intends to repair and
  strike, and this repository is retiring them (seq 9, `blocker-1-retired`).
  "No exempt commit in range" is not a defect. It is a state this tree is in on
  most days and will re-enter whenever the pull-request range holds no
  grandfathered commit, so filing it as a blocker would mean carrying it on the
  standing list forever for something nobody plans to leave.
- **The two tests are tagged, not excused.** `tests/Trailers.Tests.ps1` — the
  Co-Authored-By falsification and the empty-exemption-list falsification —
  each carry `-Tag 'SkipWhen:no-exempt-commit-in-range'` beside the existing
  `-Skip:$NothingToFalsify` from `47e2031`. The tag is on the two `It`s and not
  on the `Describe`, because the sibling "passes, using the exemption" does not
  skip and must not inherit a justification it never needed.
- **The gates now report WHY.** Both print justified skips grouped by reason.
  `output/incontainer.json` gains `justified_skips[]`, each entry carrying
  `test`, `result` and `reason`; `unjustified_skips` keeps its meaning and is
  now empty. A green log that says "skipped: 2" tells a reader nothing they can
  act on.
- **The rule is written once.** `Get-SkipJustification` lives in
  `build/Build.Helpers.psm1` — plain PowerShell, no Invoke-Build dependency,
  which is why the container can import it from the `/work` bind mount. The two
  gates remain two implementations and still differ on `NotRun`: the container
  run carries an `ExcludeTag` filter and the host run does not. They no longer
  differ on what a justification *is*.

**Tested:** passed=150 failed=0 skipped=2 — in-container, `pwsh 7.6.6`,
Pester 6.1.0, uid 1001, 21 Docker-tagged tests `NotRun` by design and excluded
from both skip lists. Host `Test.Unit`: passed=171 failed=0 skipped=2
NotRun=0 Inconclusive=0. Before this change both runs were exit 1 on those same
numbers; only the verdict on the two skips moved.

**Failed:** none.

**Missing:**

- The gate is still not in the CI required set. That is I7, explicitly out of
  scope here, so `config/repo.json -> required_checks` is untouched.
- `scripts/state.ps1` still refuses to run in this repository — it asserts the
  origin is `claude.pwsh.image.builder` and exits 1. Every state block in this
  run, including the one in the pull request, is hand-assembled. Listed, not
  fixed.
- `scripts/ci/Test-PushGuard.ps1:44` names `config/trailer-grandfather.txt` in
  its doc comment; the file is at `.continuity/trailer-grandfather.txt`. A
  stale path in prose, no behaviour attached. Listed, not fixed.
- `docs/plans/ACTIVE.md` still describes `feature/env-local` from 2026-09-21,
  two features ago. `AGENTS.md`'s stale-plan STOP is recorded as SUSPENDED in
  the disagreement table on the grounds that the file does not exist; it does
  exist. Listed, not fixed — deciding it is not this run's job.

**Blockers:**

- **No signing key.** Not touched. Nothing signs anything; `actor` and
  `LEDGER_PRINCIPAL` are operator-asserted and are places to be caught lying,
  not signatures.
- **Command-hook timeout fails open.** Not touched. The 15s PreToolUse timeout
  is Claude Code semantics; a sentinel that hangs is a sentinel that is not
  consulted.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is
  not relisted; see the 2026-09-21 section for its history.

**Ledger head hash:** `ade4061216bd49047c169c95b23ae0eb4b508114c19180ae1a622d5204f6b3ea`
(3 receipts at `output/ledger/ledger.jsonl`, written by the sentinel baked into
the image and verified by `Get-LedgerVerify`. It moves on every
`Test.InContainer` — receipts accumulate by design — so `Goal.Update` checks
its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
— canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged by this
run and re-verified by `Bootstrap`.

**Forensic chain:** the decision was recorded *before* the edit, at seq 10,
`kind=decision`, `subject=skip-justification-form`, `prev f05b175d`,
`self f88886e6`. `Goal.Update` appends its own `verification` record at the end
of this run, so this run adds two records, not one.

**Falsified, because a gate that only ever says yes is the honour system with
extra steps.** A scratch untracked `tests/Scratch.Falsify.Tests.ps1` carrying
one skip with no tag and one tagged `SkipWhen:NotAKebabReason` — a spelling the
pattern rejects — drove both gates red: `Test.Unit` exit 1 and
`Test.InContainer` exit 1, each naming both scratch skips while still reporting
the two real ones as justified. skipped=4 in both runs. The scratch was then
removed and the tree verified clean.

## 2026-09-21 06e738d run-01

Getting the image from "a hook exists" to "the hook is proven".

**Changed:**

- **Base image.** `mcr.microsoft.com/powershell:7.4-ubuntu-22.04` is gone from
  both images — deprecated, last published 2025-02, no 7.6 tag to move to.
  Both now pin `ubuntu:24.04@sha256:008173c2…` by digest and install
  PowerShell 7.6.6 from the GitHub release tarball, with `sha256sum -c` run
  **before** `tar -xzf`. The three pins are identical across both Dockerfiles
  and a test asserts they have not drifted.
- **Sentinel.** Rewritten to the current PreToolUse contract. A deny is now
  `hookSpecificOutput.permissionDecision` on stdout with **exit 0**; the old
  version emitted a deny body and then exited 2, so the body was discarded
  every time and the reason never reached anyone. Internal failures are
  stderr + exit 2 with empty stdout — fail closed. One script, one `-Mode`
  switch, both images; the developer image's second always-allow copy is
  deleted.
- **Receipts.** Every decision, allow and deny alike, appends one Ledger
  record before the decision is returned. A failed append is exit 2. Schema v1
  is untouched at eight keys; the sentinel expresses itself in the existing
  fields and hashes the raw stdin payload, so a receipt proves what the
  sentinel saw rather than what it later said about it.
- **Ledger vendored.** Both images copy `vendor/claude.build.ledger/src/ledger`
  to `/opt/leash/ledger`, root:root 0555, from the build context.
- **Entrypoint.** `entrypoint.sh` deleted, replaced by `entrypoint.ps1`. The
  `# TODO: call Get-LedgerVerify` is now an actual call. Policy validation is a
  JSON-structure check, not three greps that would pass on a settings file
  merely *mentioning* `PreToolUse` in a comment. Seven distinct exit codes
  (10–15) with one line of reason each.
- **Managed settings.** `permissions.deny` lists `Bash`, `Shell(*)`, `Edit(*)`,
  `Write(*)`. `permissions.allow` is **empty in both images** — the developer
  image's old `["Bash(pwsh *)", "Bash(python *)", "Bash(git *)"]` would have
  silently defeated its own sentinel under claude-code#18312. The entrypoint
  refuses to boot (exit 11) if a gated tool ever reappears there.
- **Tests.** `tests/plan.failfirst.ps1` deleted and replaced by five Pester
  suites, 130 tests. `src/PlanValidator.ps1` implements the plan contract for
  real, driven by the schema file.
- **Build.** Default chain is `Bootstrap → Build.Image → Test.InContainer →
  Goal.Update`. `Test.FailFirst` and the stub-scaffolding `Images.Build.Agent`
  are deleted; no task creates the file it is checking any more.
- **Continuity.** `scripts/forensic.ps1` is a byte-identical copy of
  `claude.build.ledger`'s (sha256 `ad16a85b355e0090…`), so both repos' chains
  share a format and a verifier.

**Tested:** passed=109 failed=0 skipped=0 — in-container, `pwsh 7.6.6`,
`Pester 6.1.0`, uid 1001, non-root. 21 further tests are tagged `Docker` and
excluded in-container (no daemon in there); they run on the host via
`Test.Unit` and cover both built images. Host run: 109 passed, 0 failed,
0 skipped with the same exclusion. `Invoke-Build Bootstrap, Build.Image,
Test.InContainer` → `Build succeeded. 5 tasks, 0 errors, 0 warnings`.

**Failed:** none.

**Missing:**

- No agent image. `Images.Build.Agent` was deleted rather than kept, because it
  scaffolded a placeholder Dockerfile on the deprecated base with a
  `# TODO: implement` in it the first time anyone ran it. There is nothing to
  build yet; when there is, it gets built properly.
- `Test.Unit` is not in the default chain, per the run order. The default chain
  reaches the host-only Docker-tagged assertions through `Invoke-Build Full`.
- `plans/` contains no plans, so `Plan.Check` validates the schema and the
  validator but has nothing to run them against.
- Claude Code is installed from `https://claude.ai/install.sh`, which is
  fetched at build time and not pinned by hash. The version is pinned by ARG;
  the installer script itself is not. Not in scope for run-01, but it is the
  one unverified download left in the image.

**Blockers:**

- **The receipt-append export — RETIRED 2026-09-23, and listed here as history.**
  At the time of this run the Ledger exported no receipt-append function:
  `Add-LedgerRecord` existed at `Ledger.psm1:298` but was absent from
  `Export-ModuleMember` at `Ledger.psm1:1121`, so the sentinel reached it
  through the module's own session state — a coupling to a private name.
  `Get-LedgerVerify` *was* exported even then, so the entrypoint's chain check
  was live and needed no `-WhatIf` guard. The fix landed upstream: at vendor pin
  `a68664e` the name is exported by both `ledger.psd1:9` and
  `ledger.psm1:1121-1122`, `hooks/sentinel.ps1` calls it plainly, and
  `tests/Sentinel.Tests.ps1` asserts the export rather than the workaround.
  Retirement recorded on the forensic chain at seq 9, `blocker-1-retired`.
- **No signing key.** Not touched, per the run order. Nothing signs anything.
- **Command-hook timeout fails open.** Not touched, per the run order. The 15s
  PreToolUse timeout is Claude Code semantics; a sentinel that hangs is a
  sentinel that is not consulted.
- **Identity is operator-asserted.** Not touched, per the run order.
  `LEDGER_PRINCIPAL` is whatever `docker run -e` says it is. It is not a
  signature; it is a place to be caught lying.

**Ledger head hash:** `7e7604105df9555bb93bff22caeca213cb3f554b4604e20c318003f7d8c3822c`
(3 receipts at `output/ledger/ledger.jsonl`, written by the sentinel baked into
the image, chain verified by `Get-LedgerVerify`. This is the head the forensic
record for this run names, so the two agree. It moves on every
`Test.InContainer` — receipts accumulate by design — so `Goal.Update` checks
its shape, not its value; pinning it would make the chain red for the next
person to run it.)

**Forensic anchor:** `records=1 git=06e738d tip=a476fdfdfd48f655af413d2057e8ff4f58966aa7f653f64963500f724706a140`
— `.continuity/forensic.jsonl`, chain OK. Tamper-evident, not tamper-proof:
keep this line somewhere off the tree.

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
— canonical sha256 (keys sorted ordinal, no whitespace) of
`prompts/assessment.2026-09-21.json`. That file did not exist in the repo; it
was written from the bytes carried inline in the run order, in canonical form,
so the file on disk **is** the bytes that hash and `sha256sum` alone verifies
it. The gate was falsified on purpose before being trusted.

### Defects found by running things, not by reading them

1. `install.sh` follows `$HOME`, so Claude Code installed into `/root/.local`
   (mode 0700). The build was green; `claude --version` failed at run time for
   the non-root user with "not found", and `CMD` is `["claude"]`.
2. `entrypoint.ps1` had a `param()` block, so PowerShell bound the *command's*
   flags to the script: `docker run <img> pwsh -NoProfile -c 'exit 0'` died
   with "A parameter cannot be found that matches parameter name 'NoProfile'".
3. `$payload = $raw | ConvertFrom-Json` in the sentinel — the pipeline unrolls,
   so `[{"tool_name":"Bash"}]` was accepted as a valid payload while a
   two-element array was correctly rejected. Behaviour that depended on the
   length of the thing being rejected.
4. The same enumeration trap twice more in `src/PlanValidator.ps1`: `return`
   from a scriptblock, and an `if` used as an expression.
5. My own skip-guard counted Pester's `NotRun` (tag-excluded) as an
   undocumented skip, which would have failed the chain over the 21 Docker
   tests that are excluded on purpose.

## Merged from docs/END_GOAL.md (Grok, b0232b8)

BLOCKER-11: this repository carried two files named `END_GOAL.md`. The root one is
load-bearing - `Invoke-Build Goal.Update` reads it and fails the build without a section
for the run. The second was created on `origin` by Grok and never merged.

The content below is Grok's, moved VERBATIM and not edited. `docs/END_GOAL.md` is deleted
in the same commit. Nothing is lost; it changes address and says whose it is.

Note a claim in it that later passes settled: "`Add-LedgerRecord` not in
`FunctionsToExport`. Fix in `claude.build.ledger`, then pin bump." It was true when Grok
wrote it and it is history now - at vendor pin `a68664e` the name IS in `FunctionsToExport`
(`ledger.psd1:9`) and the pin bump has landed. Grok's words above are left exactly as
written; this note is where the correction lives, because editing an attributed section to
agree with a later fact is how a record stops being one.

One objection that travelled with that claim is NOT settled upstream, and is not quietly
dropped here. The earlier text cited "the compliance plan's D7" for it: exporting the
function raw means a receipt can be appended with no validated output behind it, so the
decision was `Add-LedgerReceipt`, a constrained wrapper, rather than the raw function.
**That plan file is not in this tree** - `docs/plans/` was pruned to code-named files at
birth (forensic seq 1), and `git grep` finds no D7 here - so the citation is carried, not
verifiable from this repository. What IS measurable, re-measured 2026-09-23 at vendor pin
`a68664e6b9938773478d967348b590f487fe2443`: `Add-LedgerReceipt` exists in neither this tree
nor `vendor/claude.agent.core` - `git grep` returns nothing in core, and here it returns
only the two prose lines in this note - while core exports the raw `Add-LedgerRecord` as one
of five names at `modules/ledger/ledger.psd1:9`.

**Where it stands, decided 2026-09-23: OPEN IN CORE, CLOSED IN IMAGES.** A wrapper over a
Ledger export is Ledger API, and this repository consumes core rather than adding to it -
there is no place here to put an `Add-LedgerReceipt` that would not immediately belong to
core. So the objection stops being carried as an unmet obligation of THIS tree, which is how
the line above used to read, and is carried instead as an open objection against core at the
pin named. No wrapper is written here and core is not touched. What this repository did change
is smaller and is not offered as meeting the objection: the sentinel depends on a public name
instead of a private one. Forensic chain seq 12, `tidy-before-promotion-six-items`.

## 2026-09-21 — Grok review of oneshot (this file created on origin)

- Agent: Grok
- Remote main at write: `397f631`
- Remote develop at write: `57637ae`
- PR #5 develop→main: still open; do not merge until split is repaired without force-push
- Fable oneshot: chain claimed `COMBINED 34c940ab…` / tip `052d2db7…` / git `eb32496`. Dump not visible on origin/main at review time — treat as local until pushed.
- Ledger: not UNWIRED. `pending-exports` = `Add-LedgerRecord` not in FunctionsToExport. Fix in `claude.build.ledger`, then pin bump.
- Path to main: feature → main while develop CI rejects run-01. Later merge main *into* develop. No rebase of run-01.
- Blockers: submodule export line; oneshot artifacts not on remote; ArgumentCompleters `#Requires`; `*.log` vs TRANSCRIPT.log; PR #5 stale body.
