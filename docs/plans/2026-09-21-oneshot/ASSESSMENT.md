# ASSESSMENT — oneshot 2026-09-21

Root: `claude.pwsh.image.builder`
Branch: `feature/oneshot-2026-09-21`, cut from `f3daad8` (**not** from `main` — see PUSHBACK P2)
Prior assessment hash: `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`

Method: read-only interrogation of the working tree and git history. Nothing was executed in a
container this run, so every claim below is a claim about **files**, not about a passing build.
Where the distinction matters it is stated.

---

## PUSHBACK

The run order describes a tree that stopped existing eight commits ago.

**P1 — §1 and §5 are stale.** `feature/run-01-leash-hardening` is 8 commits ahead of `main`
(`git rev-list --left-right --count main...feature/run-01-leash-hardening` → `0  8`) and local
only; it has no upstream. run-01 already landed three of the four items §5 lists as
"implement-allowed", and the fourth is a no-op:

| §5 item | State |
|---|---|
| 1. `config/contracts.json` + schema | **not done** — this run does it |
| 2. unify both sentinels to §3 | done in run-01/2; the second sentinel was deleted, not unified |
| 3. replace `tests/plan.failfirst.ps1` | done in run-01/5; the file and its `Test.FailFirst` task are gone |
| 4. normalize `#Requires` above 7.4 | no-op; nothing is above 7.4. But one script has **no header at all** — see §1.8 and BLOCKER-10 |

Several §1 questions are therefore questions about deleted files. They are answered as
"absent, here is what replaced it" rather than left blank.

**P2 — branching from `main` would have produced a false assessment.** §0 says
`feature/oneshot-2026-09-21 (from main)`. `main` is at `397f631`, which predates every run-01
commit. A dump cut from there would have described the deprecated base image, the bash entrypoint
and the fake fail-first test as live facts. The branch was cut from `f3daad8` instead. If the
operator wanted a genuine fresh start from `main`, this branch is wrong and should be recut.

**P3 — the prior hash is an input that has already been consumed.** `798b10ee…` is the canonical
sha256 of `prompts/assessment.2026-09-21.json`. It is already pinned at `.build.ps1:79` as
`$Build.AssessmentSha`, already recorded at `END_GOAL.md:113`, and already named as evidence in
`.continuity/forensic.jsonl` seq 1. "Continue the chain from it" therefore means continuing from
the forensic tip `a476fdfd…`, not from the assessment hash. `HASHES.txt` records both.

**P4 — there is a blocker the run order does not know about, and it is larger than anything in
§1.** See BLOCKER-5: `main` and `develop` have diverged into two incompatible repositories, and
run-01 was built on the wrong side of the split.

**P5 — §4 defers `config/ledger.json` until "exports are known". They are known.** The vendored
`Ledger.psd1` exports four functions. The gap is narrower and sharper than "unknown": one specific
function that the sentinel depends on is not among them.

**P6 — §7 asks for AGENTS.md and BREADCRUMBS.md to be told that every run ends in END_GOAL.md.
Both already say so**, in detail, added by run-01/7. Only the COMBINED-hash field is new, and only
that was added. Restating the rest would have been noise.

---

## §1 — Interrogation

### 1. `hooks/sentinel.ps1` — what it denies, stdout shape, exit codes

Denies the four tools in the `$GatedTool` param default at `hooks/sentinel.ps1:73`: `Bash`,
`Shell`, `Edit`, `Write` — under `-Mode Enforce` only.

| Case | stdout | exit |
|---|---|---|
| gated tool, Enforce | `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`, compressed | 0 |
| non-gated tool | `{}` | 0 |
| any tool, Observe | `{}` | 0 |
| stdin unreadable, empty, not a JSON object, not valid JSON, no `tool_name`, ledger dir unmounted, ledger write failed | nothing on stdout; `leash-sentinel: <reason>` on stderr | 2 |

**This already is the §3 contract, exactly.** The reason string carries the receipt self-hash and
the principal. stdout is written once, via `[Console]::Out.Write`, and the file's own `.NOTES`
block explains why nothing else may touch it.

Two design points worth keeping rather than "cleaning up":

- The JSON-object check is made against the **raw text** (`$raw.TrimStart().StartsWith('{')`), not
  the parsed result, because the pipeline unrolls: piping `[{"tool_name":"Bash"}]` through
  `ConvertFrom-Json` leaves the inner object behind, so a one-element array would have passed every
  later check while a two-element array failed. A validator whose behaviour depends on the length
  of what it is rejecting is not a validator.
- A payload with no `tool_name` is a hard failure, not a tool named `unknown`.

### 2. `images/developer/hooks/sentinel.ps1`

**Does not exist.** Deleted in run-01/2. `images/` now holds exactly three files:
`developer/Dockerfile`, `developer/managed-settings.json`, `developer/src/.gitkeep`.

The developer image copies the same `hooks/` directory and selects behaviour with a switch: its
`managed-settings.json` invokes `sentinel.ps1 -Mode Observe`, and `ENV LEASH_MODE=Observe` is the
fallback default. Yes, it writes a receipt — every decision, allow and deny alike, appends one
Ledger record **before** the decision is returned, and a failed append is exit 2.

### 3. Entrypoint

`entrypoint.ps1`. **PowerShell, not bash** — `entrypoint.sh` was deleted in run-01/3. There is no
no-bash drift left to record.

It does not grep three keys. It parses the settings file as JSON and checks structure:
`allowManagedHooksOnly` present and `true`, `disableBypassPermissionsMode` present and `true`,
`hooks.PreToolUse` present and non-empty, then walks `permissions.allow` for any gated tool. The
file's own comment gives the reason: a grep passes on a settings file that merely *mentions*
`PreToolUse` inside a comment.

The Ledger `# TODO` is gone; it is a live `Get-LedgerVerify -LedgerPath $ledgerFile` call. Seven
distinct exit codes, 10–15, one reason each, asserted separately by `tests/Entrypoint.Tests.ps1:59`.

One deliberate absence worth not "fixing": there is **no `param()` block**, because a param block
made PowerShell bind the *command's* flags to the script — `docker run <img> pwsh -NoProfile -c
'exit 0'` died on "A parameter cannot be found that matches parameter name 'NoProfile'".
Configuration comes from the environment instead.

### 4. `schemas/plan.schema.json` — required keys

Draft 2020-12, title `AgentPlan`, `type: object`.
Required: **`id`** (string), **`steps`** (array, `minItems: 1`), **`expected_output`** (string).
Optional: `skills_to_build` (array of string).

### 5. `tests/plan.failfirst.ps1`

**Does not exist.** Deleted in run-01/5 together with the `Test.FailFirst` task. The function it
called, `Test-PlanStructure`, existed nowhere — so it failed with "command not found" and the task
read any failure as proof the discipline worked. It would have stayed green against a validator
that accepted every plan in existence.

Replaced by `src/PlanValidator.ps1` (a real `Test-PlanStructure`, driven by the schema file) and
five Pester suites: `Entrypoint`, `Image`, `Plan`, `Sentinel`, `Settings`, plus `TestHelpers.psm1`.

### 6. `vendor/claude.build.ledger`

**Populated.** Submodule at `ed9c9d79856b4590b64eb2f0229dee8775a903d5` (`heads/main`), module
`ModuleVersion = '0.1.0'`, `PowerShellVersion = '7.4'`.

`FunctionsToExport`, verbatim:

    Invoke-LedgerForce, Get-LedgerStatus, Get-LedgerVerify, Get-LedgerEntry

- **chain-verify: `Get-LedgerVerify`** — exported, and live: `entrypoint.ps1` calls it at boot and
  exits 14 on a broken chain.
- **receipt-append: `pending-exports`** — `Add-LedgerRecord` exists at `Ledger.psm1:298` but is
  absent from `Export-ModuleMember` at `Ledger.psm1:1121`. `hooks/sentinel.ps1` reaches it through
  the module's own session state, which is a coupling to a private name.

So the status is **not** UNWIRED. It is wired, with one named private-name coupling — BLOCKER-1,
and the fix belongs in `claude.build.ledger`, not here.

### 7. Dockerfiles

Two: `Dockerfile` (the enforcing leash image) and `images/developer/Dockerfile` (observing). Both
carry identical pins:

    BASE_IMAGE           ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3
    PWSH_URL             .../PowerShell/releases/download/v7.6.6/powershell-7.6.6-linux-x64.tar.gz
    PWSH_SHA256          ddbc4a2d113bbd46d283cfedcbcd117a70caefd7673f41f2b4e0000badf103bc
    PESTER_VERSION       6.1.0
    CLAUDE_CODE_VERSION  latest

`sha256sum -c -` runs **before** `tar -xzf`. `tests/Image.Tests.ps1:38` asserts the two files have
not drifted apart.

**No reference to `mcr.microsoft.com/powershell` survives anywhere in the tree.** The deprecation
is recorded as a *rejected* claim in `prompts/assessment.2026-09-21.json`: those images were last
published 2025-02 and no 7.6 tag exists.

One unpinned download remains: Claude Code installs from `https://claude.ai/install.sh`, fetched at
build time. The version is pinned by ARG; the installer script is not.

### 8. `#Requires -Version` in repo-owned scripts

22 repo-owned scripts scanned (`vendor/`, `.git/` and `output/` excluded).
**21 carry `#Requires -Version 7.4`. Nothing is above 7.4, so §5 item 4 is a no-op.**

**But one file carries no header at all: `build/ArgumentCompleters.ps1`.** The hard law says
`#Requires -Version 7.4` goes on *every* repo-owned script, so that is a violation — a different
one from the drift §5 anticipated, and invisible to the obvious check. Grepping for
`#Requires -Version` and reading the versions back can only ever find files that already comply;
the file with no header does not appear in the results at all. It was found by counting scripts
and subtracting, in `verify.ps1`, not by reading.

**Not fixed this run.** §5 item 4 permits normalizing headers *above* 7.4 and this is a missing
header, so fixing it is outside the implement-allowed list. It is a one-line change and it is
recorded as BLOCKER-10.

The 21 compliant files: `.build.ps1`, `build/Build.Helpers.psm1`, `build/InContainer.Bootstrap.ps1`,
`build/InContainer.Test.ps1`, `build/tasks/{Core,Goal,Images,Plan,Skills,Test}.build.ps1`,
`entrypoint.ps1`, `hooks/sentinel.ps1`, `scripts/forensic.ps1`, `src/PlanValidator.ps1`,
`tests/{Entrypoint,Image,Plan,Sentinel,Settings}.Tests.ps1`, `tests/TestHelpers.psm1`, and this
run's `docs/plans/2026-09-21-oneshot/verify.ps1`.

The only `7.6` mentions are runtime asserts, never script headers — which is the correct split and
matches §8's "two different contracts; do not merge them".

### 9. Managed settings

Path in both images: `/etc/claude-code/managed-settings.json`. Owner `root:root`. Directory `0555`,
file `0555` — the directory too, because a writable directory allows unlink-and-recreate that a
read-only file alone does not prevent. Asserted at `tests/Settings.Tests.ps1:115`.

| | `permissions.deny` | `permissions.allow` |
|---|---|---|
| leash (`managed-settings.json`) | `["Bash","Shell(*)","Edit(*)","Write(*)"]` | `[]` |
| developer (`images/developer/managed-settings.json`) | `[]` | `[]` |

**`permissions.allow` contains none of the gated tools in either image**, and `entrypoint.ps1`
refuses to boot with exit 11 if one ever reappears there — designing around claude-code#18312,
where a hook's `permissionDecision` is ignored for an allow-listed tool.

The developer image's empty deny list is deliberate and correctly reasoned:
`tests/Settings.Tests.ps1:106` asserts `deny.Count -eq 0` *because* deny beats the hook, so Observe
must not deny. An Observe image that denied would make the mode pointless.

**Observation, not a finding:** `Bash` is listed bare while the other three are globbed `X(*)`. Both
forms appear valid and I cannot prove the asymmetry is a defect from files alone. Recorded so the
next shot decides it deliberately rather than inheriting it.

### 10. `config/`, `END_GOAL.md`, `.continuity/forensic.jsonl`

- **`config/`** — did **not** exist before this run. This run creates it holding `contracts.json`
  only.
- **`END_GOAL.md`** — exists, one section: `## 2026-09-21 06e738d run-01`.
- **`.continuity/forensic.jsonl`** — exists, **one record**: seq 1, actor `claude`, kind
  `verification`, `prev` empty (genesis), self
  `a476fdfdfd48f655af413d2057e8ff4f58966aa7f653f64963500f724706a140`. `scripts/forensic.ps1` drives
  it and is a byte-identical copy of the one in `claude.build.ledger`, so both chains share a format
  and a verifier.

### 11. Where policy is duplicated today

**The gated-tool list — nine literal sites, two forms:**

| Site | Form |
|---|---|
| `hooks/sentinel.ps1:73` | `@('Bash','Shell','Edit','Write')` |
| `entrypoint.ps1:61` | `@('Bash','Shell','Edit','Write')` |
| `managed-settings.json:5-10` | `["Bash","Shell(*)","Edit(*)","Write(*)"]` |
| `images/developer/managed-settings.json` | `[]` — the same policy in a fifth state |
| `tests/Sentinel.Tests.ps1:23` | `$script:GatedTools = @(…)` |
| `tests/Sentinel.Tests.ps1:76` | inline `-ForEach @(…)` |
| `tests/Sentinel.Tests.ps1:157` | inline `-ForEach @(…)` |
| `tests/Settings.Tests.ps1:16` | `$script:GatedTools = @(…)` |
| `tests/Settings.Tests.ps1:62` | inline `-ForEach @(…)` |
| `tests/Settings.Tests.ps1:97` | inline `-ForEach @('Bash','Shell(*)',…)` |

The tests assert that the runtime sites agree. **But the assertion is itself another copy of the
list**, so an edit that changes the policy and the test together passes green. The suite catches
accidental drift and cannot catch intentional drift — a detector cut to the shape of the fix rather
than the shape of the failure.

**Version and pin duplication:**

| Thing | Sites |
|---|---|
| PowerShell 7.6 floor | `build/InContainer.Bootstrap.ps1:43` **and** `build/InContainer.Test.ps1:43` — two independent `[version]$MinimumPSVersion = '7.6'` defaults |
| pwsh tarball url + sha256 | `Dockerfile:16-17`, `images/developer/Dockerfile:16-17` |
| base image digest | `Dockerfile:15`, `images/developer/Dockerfile:15` |
| Pester `6.1.0` | `.build.ps1` (`$Build.PesterVersion`), `Dockerfile:23`, `images/developer/Dockerfile:23` |

§6's accuracy gate "One version gate (core.json + Bootstrap)" is **not met today**: there are two
Bootstrap-side floors, not one, and three families of build-time pins duplicated across two
Dockerfiles. `tests/Image.Tests.ps1:38` pins the Dockerfiles to each other, which is drift
*detection*, not a single source.

### 12. Business outcome, one sentence

This run removes the failure class **"the policy is true in one file and false in another, and the
test suite is built from the same copies so it cannot tell"** — by naming the surface every sibling
consumes, in one validated file, before any of them is rewired to read it.

---

## §3 — Hook contract vs. what is on disk (Stream A)

| §3 requirement | `hooks/sentinel.ps1` | Verdict |
|---|---|---|
| gated → `hookSpecificOutput…deny`, exit 0, nothing else on stdout | exact, single `[Console]::Out.Write` | **match** |
| non-gated → `{}`, exit 0 | exact | **match** |
| internal error → stderr, exit 2 | `Exit-Closed`, every failure path | **match** |
| developer image = same script, `-Mode Observe`, always allow, still writes a receipt | one script, `-Mode` switch, receipt before decision | **match** |
| managed-settings `deny` lists the gated tools; `allow` never contains them | leash denies all four; both images' `allow` empty; entrypoint exits 11 on regression | **match** |

**Zero diffs. §5 item 2 is already satisfied.** This is a file-level verdict; it was not re-proved
by piping a payload this run, because §5 forbids running the chain and `tests/Sentinel.Tests.ps1`
already does exactly that — Enforce, Observe, fails-closed, and a malformed-stdin table including
the unrolled-array case.

---

## §D — Test taxonomy (Stream D)

Five suites, 130 tests. `tests/TestHelpers.psm1` carries `Invoke-Sentinel`, `New-Payload` and
`Get-Settings`.

| Suite | Describes | Tag |
|---|---|---|
| `Entrypoint.Tests.ps1` | refusals have distinct exit codes (`:59`); what it must NOT refuse (`:156`) | none |
| `Image.Tests.ps1` | Dockerfile pins, static (`:38`); image builds and runs correctly (`:110`) | `Docker` on `:110` |
| `Plan.Tests.ps1` | plan schema (`:34`); `Test-PlanStructure` (`:59`) | none |
| `Sentinel.Tests.ps1` | vendored Ledger dependency (`:51`); Enforce (`:68`); Observe (`:141`); fails closed (`:164`) | none |
| `Settings.Tests.ps1` | per-image settings (`:36`); denies the gated tools (`:94`); enforce vs observe (`:106`); Dockerfiles lock policy down (`:115`) | none |

**There are no `contract:*` or `exception:*` tags today.** The only tag in the suite is `Docker`,
used to exclude the 21 host-only tests in-container where there is no daemon. The §4 naming rule
(`tests/<Name>.Tests.ps1` tagged `contract:<name>`, `exception:<id>`) is **proposed, not
implemented** — it lands with the config surface, since a `contract:policy` tag means nothing until
`config/policy.json` is the thing being contracted.

**No `-Skip` or `-Pending` anywhere in the suite**, so §6's gate on undocumented skips passes
trivially. The 21 `Docker` tests are excluded by tag, which Pester reports as `NotRun`, not
`Skipped` — a distinction that already bit once, when a skip-guard counted tag-excluded tests as
undocumented skips and would have failed the chain over tests excluded on purpose.

---

## §B — Drift map (Stream B)

Consolidated from 1.8 and 1.11.

| Drift class | Sites | Single source today? |
|---|---|---|
| gated tool list | 9 literals, incl. 6 in tests | **no** |
| script version floor (7.4) | 21 headers agreeing, **1 script with no header** | no — BLOCKER-10 |
| runtime version floor (7.6) | 2 independent defaults | **no** |
| base image digest | 2 | no — cross-asserted |
| pwsh tarball url + sha | 2 each | no — cross-asserted |
| Pester version | 3 | **no** |
| ledger module path | `hooks/sentinel.ps1`, `entrypoint.ps1`, both Dockerfiles | **no** |
| ledger path `/ledger/ledger.jsonl` | `hooks/sentinel.ps1`, `entrypoint.ps1` | **no** |

---

## §E — Ledger facts (Stream E)

Not UNWIRED. Submodule populated and pinned at `ed9c9d7`.

| Need | Export | Status |
|---|---|---|
| verify the chain | `Get-LedgerVerify` | **known**, called live by `entrypoint.ps1` |
| append a receipt | — | **pending-exports** — `Add-LedgerRecord` is private |
| read one record | `Get-LedgerEntry` | known, unused here |
| status | `Get-LedgerStatus` | known, unused here |
| force loop | `Invoke-LedgerForce` | known, unused here |

`config/ledger.json` is **not** written this run. No hash algorithm, receipt byte layout or record
schema is asserted anywhere in this dump: the sentinel writes through the module and does not
reimplement the format, which is the property that keeps schema v1's eight keys valid.

---

## BLOCKER-5 — the finding the run order does not contain

`main` and `develop` have diverged into two incompatible repositories, and run-01 sits on the
`main` side.

    git rev-list --left-right --count main...develop  →  5   16

`develop` carries a CI workflow (`.github/workflows/ci.yml`, absent on both `main` and the run-01
branch) whose `Guard - handoff intact` step requires nine files to exist. Eight of them exist on
`develop` and on **none** of run-01's commits:

| File | `develop` | run-01 |
|---|---|---|
| `FLOW.md` | yes | **no** |
| `AFTER-CLAUDE-COMMITS.md` | yes | **no** |
| `.ALLAGENTS.md` | yes | **no** |
| `scripts/snake.ps1` | yes | **no** |
| `scripts/state.ps1` | yes | **no** |
| `docs/skills/plan-authoring.md` | yes | **no** |
| `docs/skills/business-outcomes.md` | yes | **no** |
| `docs/skills/session-handoff.md` | yes | **no** |

That is not the only step that would fail. On a PR into `develop`, run-01 also breaks:

- **`Guard - no Co-Authored-By trailers`** — `develop`'s `AGENTS.md:54` says "No `Co-Authored-By`
  trailers", and the guard greps `^co-authored-by:` across `base..HEAD`. **All eight run-01 commits
  carry one.** The entire branch history is CI-rejectable, and rewriting it is the only fix, which
  conflicts with "No force-push" four lines later in the same file.
- **`Shellcheck entrypoint`** — run-01 deleted `entrypoint.sh`. The step either fails or passes
  vacuously; either way it is no longer checking the entrypoint.
- **`Snake dry-run (plans well-formed)`** — invokes `scripts/snake.ps1`, which run-01 does not have.

**Nothing in `END_GOAL.md` records any of this**, because run-01 never targeted `develop`. This is
the single largest open question in the repository and it is a decision for the operator, not a
code change: either `develop` is abandoned in favour of the run-01 lineage, or run-01 is rebuilt to
satisfy `develop`'s guards. It is not something this shot should pick.

---

## What this shot changed

| Path | Change |
|---|---|
| `config/contracts.json` | new — §2 surface contract, five sibling rows, seven named exceptions |
| `schemas/contracts.schema.json` | new — sibling schema, validated with `Test-Json` |
| `docs/plans/2026-09-21-oneshot/*` | new — this dump |
| `AGENTS.md` | one field added to the END_GOAL table: COMBINED hash |
| `docs/BREADCRUMBS.md` | same field, same reason |

Nothing else. No Dockerfile was touched, no directory restructured, `src/PlanValidator.ps1` left
alone, `vendor/` untouched.
