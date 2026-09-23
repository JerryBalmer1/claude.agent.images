# END_GOAL.DRAFT — oneshot 2026-09-21

A draft, deliberately. It is **not** merged into `END_GOAL.md` and **not** a Goal.Update section,
because this shot did not run `Test.InContainer` and therefore has no `Tested` totals that
`output/incontainer.json` would agree with. Writing a green summary of a run that did not happen is
the exact thing the gate exists to catch, and satisfying it with invented numbers would defeat it.
See BLOCKER-9 for the second reason.

**Prior assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
**Prior forensic tip:** `a476fdfdfd48f655af413d2057e8ff4f58966aa7f653f64963500f724706a140` (seq 1)
**This run's hashes:** see `HASHES.txt`, whose final line is the COMBINED hash.

---

## Milestones

### shapes-known
**State:** done, this run.
**Blocker:** none.
**Next shot:** nothing. `ASSESSMENT.md` answers all twelve §1 questions from files, with paths, and
marks what was deleted rather than leaving it blank.

### sentinel-unified
**State:** done — run-01/2, verified by reading this run, not by running.
**Blocker:** none.
**Next shot:** nothing to unify. There is one `hooks/sentinel.ps1` with a `-Mode` switch and no
second copy. Its deny body, allow body and three exit codes match §3 exactly, and
`tests/Sentinel.Tests.ps1` already pipes fake payloads for Enforce, Observe, malformed stdin and
the unrolled-array case.

### ledger-wired-or-honest-unwired
**State:** wired, honestly, with one named gap. Not UNWIRED.
**Blocker:** **BLOCKER-1** — `Add-LedgerRecord` is defined at `Ledger.psm1:298` but absent from
`Export-ModuleMember` at `Ledger.psm1:1121`, so `hooks/sentinel.ps1` reaches it through module
session state. `Get-LedgerVerify` *is* exported and the entrypoint's chain check is live.
**Next shot:** the fix is in `claude.build.ledger`, not here — add the append function to
`FunctionsToExport` in `Ledger.psd1`, bump the submodule pin, then delete the session-state call in
the sentinel. Until then the tripwire in `tests/Sentinel.Tests.ps1` keeps the breakage loud instead
of surfacing as "ledger write failed" on every hook call in production.

### config-surface-landed
**State:** started. `config/contracts.json` and `schemas/contracts.schema.json` exist and validate.
Nothing consumes them yet, which is what §5 permitted.
**Blocker:** none for what landed.
**Next shot:** `core.json`, `policy.json`, `patterns.json`, then rewire consumers one at a time —
`policy.json` first, because it has three consumers and nine duplicate literals to collapse
(§1.11). `ledger.json` stays unwritten until BLOCKER-1 clears; there is no point pinning a contract
to a function the module will not admit it has.

### pester-in-container
**State:** done at `06e738d` — `passed=109 failed=0 skipped=0`, in-container, pwsh 7.6.6,
Pester 6.1.0, uid 1001, non-root.
**Blocker:** none.
**Caveat, and it matters:** that total was **not re-verified this run**. It is quoted from
`END_GOAL.md`, which `Goal.Update` cross-checked against `output/incontainer.json` at the time. This
shot ran no container. Do not carry this number into a new Goal.Update section without rerunning the
chain.
**Next shot:** rerun `Invoke-Build` and let the gate re-prove it, rather than inheriting it.

### goal-file-mandatory
**State:** done — run-01/7. `Goal.Update` is the last task in the default chain, checks seven
required fields, and cross-checks `Tested` against `output/incontainer.json`.
**Blocker:** **BLOCKER-9** — the header pattern is built from `$Build.RunId`, pinned to the literal
`'run-01'` in `.build.ps1`. Any run with a different id can never satisfy the gate without editing
`.build.ps1` first. The gate is also date-pinned to *today*, so the existing section goes stale at
midnight and the chain is red until someone writes a new one.
**Next shot:** decide whether `RunId` moves to `config/core.json` (the natural home, and the reason
core.json wants a `run` key) or whether each run edits `.build.ps1`. The date pin is correct and
should stay.

### entrypoint-no-bash
**State:** done — run-01/3. `entrypoint.sh` deleted, `entrypoint.ps1` in its place, structural JSON
validation rather than greps, seven distinct exit codes, live `Get-LedgerVerify` call.
**Blocker:** a consequence, not a defect here — `develop`'s CI still has a `Shellcheck entrypoint`
step that now has no `entrypoint.sh` to check. Part of **BLOCKER-5**.
**Next shot:** when the branch question is settled, replace that CI step with a PowerShell syntax
check, which the workflow already does for other scripts.

### version-gate-single-source
**State:** **not done.** This is the largest remaining item inside the repo's own control.
**Blocker:** **BLOCKER-6** — the 7.6 runtime floor is two independent `[version]$MinimumPSVersion`
param defaults (`build/InContainer.Bootstrap.ps1:43`, `build/InContainer.Test.ps1:43`); the base
image digest, tarball URL and tarball sha256 are each duplicated across two Dockerfiles; Pester
`6.1.0` lives in three places. `tests/Image.Tests.ps1:38` pins the Dockerfiles to each other, which
is drift detection, not a single source.
**Next shot:** `config/core.json` holds script floor 7.4, runtime floor 7.6, the exact Pester
version, the base image digest and the tarball URL plus sha256. Bootstrap asserts against it;
Dockerfile ARGs are passed from it at build time by `Images.build.ps1`; the second floor in
`InContainer.Test.ps1` is deleted rather than kept in step.

---

## Blockers — the full list, relisted as the law requires

| # | Blocker | New this run |
|---|---|---|
| BLOCKER-1 | Ledger does not export a receipt-append function; the sentinel couples to a private name | no |
| BLOCKER-2 | No signing key. Identity is operator-asserted | no |
| BLOCKER-3 | Command-hook timeout fails open — Claude Code semantics, 15s | no |
| BLOCKER-4 | `LEDGER_PRINCIPAL` is unverifiable; it is a place to be caught lying | no |
| BLOCKER-5 | **`main` and `develop` have diverged into two incompatible repositories; run-01 cannot pass `develop` CI** | **yes** |
| BLOCKER-6 | **Version gate is not single-source: two runtime floors, three pin families** | **yes** |
| BLOCKER-7 | **The gated-tool list is nine literals, six of them inside the tests that assert it** | **yes** |
| BLOCKER-8 | Claude Code installer script is fetched unpinned at build time | no |
| BLOCKER-9 | **`Goal.Update` pins `RunId` to `run-01` in `.build.ps1`; no other run can satisfy the gate** | **yes** |
| BLOCKER-10 | **`build/ArgumentCompleters.ps1` carries no `#Requires -Version` header, which the hard law requires on every repo-owned script** | **yes** |

BLOCKER-5 is the one that needs an operator decision rather than a commit. Everything else is work.
BLOCKER-10 is a one-line fix, deliberately left undone because §5 permits normalizing headers
*above* 7.4 and this is a header that is absent — a different defect, and out of scope for a shot
that was told to freeze shapes.

**How BLOCKER-10 was found, because the method matters more than the defect.** Grepping for
`#Requires -Version` and checking the versions can only return files that already comply. The file
with no header is not in the result set at all, so the check that looks correct is structurally
incapable of finding it. `verify.ps1` counts every repo-owned script and subtracts the ones that
matched, which is why the number 22 against 21 is printed rather than just the list. Any future
check on this law should report the miss count, not the hit list.

---

## What this shot did not do, on purpose

Per §5, this run did not rewrite Dockerfiles, land `PlanValidator` changes, restructure
directories, or touch `vendor/`. It did not write `config/core.json`, `policy.json`, `patterns.json`
or `ledger.json` — §5 permitted `contracts.json` only. It did not merge a section into `END_GOAL.md`
and did not run `Invoke-Build`.
