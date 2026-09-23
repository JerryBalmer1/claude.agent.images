# END_GOAL

The state of this repository, recorded by the run that changed it.

`Goal.Update` is the last task in the default chain and it fails the build
unless the newest run has a section here. See `AGENTS.md` for the required
fields. The `Tested` totals are cross-checked against
`output/incontainer.json`, so a green summary of a run that did not happen
fails the build rather than being believed.

---

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

One objection that travelled with that claim is NOT settled, and is not quietly dropped
here. The earlier text cited "the compliance plan's D7" for it: exporting the function raw
means a receipt can be appended with no validated output behind it, so the decision was
`Add-LedgerReceipt`, a constrained wrapper, rather than the raw function. **That plan file
is not in this tree** - `docs/plans/` was pruned to code-named files at birth (forensic
seq 1), and `git grep` finds no D7 here - so the citation is carried, not verifiable from
this repository. What IS measurable: `Add-LedgerReceipt` exists in neither this tree nor
`vendor/claude.agent.core` at `a68664e`; upstream exported the raw `Add-LedgerRecord`. The
objection therefore stands unmet. What changed is only that the sentinel depends on a
public name instead of a private one, which is a smaller claim than the wrapper asked for.

## 2026-09-21 — Grok review of oneshot (this file created on origin)

- Agent: Grok
- Remote main at write: `397f631`
- Remote develop at write: `57637ae`
- PR #5 develop→main: still open; do not merge until split is repaired without force-push
- Fable oneshot: chain claimed `COMBINED 34c940ab…` / tip `052d2db7…` / git `eb32496`. Dump not visible on origin/main at review time — treat as local until pushed.
- Ledger: not UNWIRED. `pending-exports` = `Add-LedgerRecord` not in FunctionsToExport. Fix in `claude.build.ledger`, then pin bump.
- Path to main: feature → main while develop CI rejects run-01. Later merge main *into* develop. No rebase of run-01.
- Blockers: submodule export line; oneshot artifacts not on remote; ArgumentCompleters `#Requires`; `*.log` vs TRANSCRIPT.log; PR #5 stale body.
