# END_GOAL

The state of this repository, recorded by the run that changed it.

`Goal.Update` is the last task in the default chain and it fails the build
unless the newest run has a section here. See `AGENTS.md` for the required
fields. The `Tested` totals are cross-checked against
`output/incontainer.json`, so a green summary of a run that did not happen
fails the build rather than being believed.

---

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
  `jerry.infra@gmail.com` as the author of every human commit and the committer of every
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
