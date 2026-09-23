# Plan: .env.local — credentials outside the tree, loaded in one line

Date: 2026-09-21
Branch: feature/env-local
PR: (link, filled on open)
Status: executing

## Goal

Jerry can paste a real GitHub token into one gitignored file, run one command, and have
every tool in this repo see it as an environment variable — without the token ever
reaching a commit, a log line, a CI transcript, or an image layer. Done looks like:
`.env.local` exists and `git check-ignore` agrees it can never be committed;
`scripts/env.ps1` loads it and prints `NAME  set (len 93)` rather than the value;
a CI guard fails the build if any tracked file ever carries a token pattern; and the
tests that prove all three have each been watched to fail before they were made to pass.

## Context

Verified 2026-09-21 from the live tree with `git fetch --all --prune`, `git status -sb`,
`pwsh -NoProfile -File scripts/state.ps1`, `git grep`, `Test-Path` and
`Get-Module -ListAvailable`. Nothing below is carried over from a chat paste.

- `develop` is `16e98fe`, clean, level with `origin/develop`. CI green on `16e98fe`.
- No tags, local or remote. No `Co-Authored-By` anywhere on this branch.
- PR #5 (`develop` -> `main`) is **open and CONFLICTING**. Out of scope here and
  untouched by this plan, but it means this work will sit on `develop` until Jerry
  resolves that merge. Flagged, not fixed.
- `docs/plans/ACTIVE.md` named `feature/operating-protocol` while HEAD was `develop` —
  the stale-plan STOP in `AGENTS.md`. Writing this plan is the legal exit from it.
- `.env.local`, `.env.example` and `.build.ps1` are all **absent**.
- `.gitignore` carries exactly one rule today (`docs/plans/*-report.md`). Every existing
  line is preserved; this plan only appends.
- `tests/` does not exist. It is created here, minimally, as the plan directing this work
  said a later plan would extend it.
- Pester **5.7.1** is available locally (6.1.0 and 3.4.0 also present, so the runner pins
  5.x explicitly rather than taking whatever loads first).
- `git grep` for `ghp_`, `github_pat_` and private-key headers over all tracked files
  returns nothing. The tree is clean of secrets **before** this change, so the new CI
  guard starts green and can only go red on a regression.

**A claim from the inbound handoff that has moved.** The handoff recorded `gh 2.14.2
(2022-07-14), STALE`. Live it is **2.101.0 (2026-09-15)**. Contradicted from the tree, as
`FLOW.md` §0 requires.

**Compliance checklist**

- **Secrets** — this plan is *entirely* about secrets, so the answer is a design, not a
  "no". No credential is written, logged, echoed or committed by anything here. The
  loader reads `.env.local` and prints only a name and a character count. `.env.example`
  carries empty values and is asserted token-free by a test. The one file that will hold
  a real token is gitignored before it is created, and a CI guard scans every tracked
  file on every PR. `docker run` receives credentials via `--env-file .env.local`,
  documented in the README and deliberately **not** baked into any image layer.
- **PII** — N/A. No personal data beyond the human gate line naming Jerry, already
  throughout the repo.
- **PCI** — N/A. No cardholder data, no CDE.
- **Network egress** — none added. `scripts/env.ps1` is pure local file I/O. The new CI
  step is `git grep` over an already-checked-out tree: no download, no new dependency.
- **Blast radius** — if every step runs wrong: a malformed `.gitignore` could fail to
  ignore `.env.local`, which is why a test asserts `git check-ignore` exits 0 and a
  planted twin proves that test can go red. The loader could leak a value, which is why a
  test feeds it a planted fake token and asserts the captured output never contains it.
  Nothing here touches `main`, a tag, a published image, or a shared environment. The
  worst realistic outcome is a red CI on a feature branch.

## Business outcome

**Risk reduction, with a measure.** Today the only way for Jerry to give this repo a
credential is to paste it into a chat or type it into a shell — both of which put the
token somewhere it cannot be revoked from. This plan takes the number of code paths that
can commit a secret from *unbounded* to *zero-by-construction*, and makes the claim
falsifiable: `git grep` over tracked files must return nothing on every PR, enforced by
CI rather than by discipline.

It also buys speed, which is what Jerry actually asked for: credential setup goes from a
re-paste every session to `Copy-Item` once, then one `-Check` command. Every downstream
plan that needs `GITHUB_TOKEN` (the terraform and accountability work) stops being
blocked on credential handling.

"Done" means a token can be supplied and consumed without existing anywhere git can see —
not that five files were written.

## Skills referenced

- plan-authoring
- business-outcomes
- secret-hygiene

## Allow-list (only these paths may change)

- `docs/plans/2026-09-21-env-local.md`
- `docs/plans/ACTIVE.md`
- `docs/plans/README.md`
- `docs/skills/secret-hygiene.md`
- `.env.example`
- `.gitignore`
- `scripts/env.ps1`
- `README.md`
- `tests/run.ps1`
- `tests/Env.Tests.ps1`
- `tests/evidence/` (transcripts of the red and green runs)
- `.github/workflows/ci.yml`

`.env.local` is created on disk but is **never** tracked; it is gitignored before it
exists. It is therefore not on this list, because nothing git sees will change.

## Do-not-touch

- `scripts/snake.ps1`, `scripts/state.ps1` — the snake and live state. Not this plan's job.
- `Dockerfile`, `entrypoint.sh`, `.dockerignore`, `managed-settings.json`, `hooks/sentinel.ps1`
  — no credential goes into an image layer, so none of these need to change.
- `FLOW.md`, `AGENTS.md`, `.ALLAGENTS.md`, `AFTER-CLAUDE-COMMITS.md` — repo law. A plan
  does not amend the law it runs under.
- `docs/plans/2026-09-20-*.md` — archived and in-flight plans are immutable records.
- Every existing line of `.gitignore` and every existing CI step. This plan appends only.

## Steps

1. Branch `feature/env-local` off `develop` at `16e98fe`. Commit this plan file and
   `ACTIVE.md` **before** any code change (`plan-authoring` step 7).
2. Write `tests/run.ps1` (Pester 5 pinned) and `tests/Env.Tests.ps1`. Run them and
   **watch them fail** — the loader does not exist yet. Capture the transcript to
   `tests/evidence/`.
3. Write `.env.example` (every variable commented with what it is, who reads it, where to
   create it; all values empty or non-secret).
4. Append to `.gitignore`: `.env.local`, `.env.*.local`, `*.tfvars`, `*.tfstate*`,
   `.terraform/`, `crash.log`, `*.pem`, `id_ed25519*`. Keep every existing line.
5. Write `scripts/env.ps1`: repo guard, `$ErrorActionPreference = 'Stop'`, reads
   `.env.local` (overridable with `-Path`), skips blanks and `#`, sets `$env:NAME`,
   strips matching quotes, expands a leading `~`, **never prints a value**. `-Require`
   throws naming what is missing. `-Check` sets nothing.
6. Create `.env.local` from `.env.example` with a LOCAL ONLY header. Leave every value
   empty — Jerry pastes the token, the agent never sees one.
7. Add the **Credentials** section to `README.md`, before the Quick start build block.
8. Write `docs/skills/secret-hygiene.md` (`.ALLAGENTS.md` requires a skill learned during
   execution to be written before the plan closes).
9. Add one CI step, `Guard - no secrets in tree`, placed first in the job so it fails
   fastest.
10. Run the tests green. Then plant each defect the plan names, watch the matching test go
    red, restore, and re-run green. Capture every transcript to `tests/evidence/`.
11. Update `## Progress`. Commit, push, open the PR into `develop`. Do not merge.

## Verify (local, no commit)

```
Set-Location '..\claude.pwsh.image.builder'
if ((git rev-parse --show-toplevel) -notmatch 'claude\.pwsh\.image\.builder$') { throw 'NOT IN IMAGE BUILDER' }
$ErrorActionPreference = 'Stop'; $PSNativeCommandUseErrorActionPreference = $true
git check-ignore -v .env.local; "IGNORED EXIT: $LASTEXITCODE (0 = ignored)"
pwsh -NoProfile -File scripts/env.ps1 -Check
git grep -nE 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' -- . ; "SECRET SCAN: $LASTEXITCODE (1 = clean)"
pwsh -NoProfile -File tests/run.ps1; "TESTS EXIT: $LASTEXITCODE"
pwsh -NoProfile -File scripts/snake.ps1 -DryRun
```

## Progress

- 2026-09-21 — Plan written and committed first, on `feature/env-local` off `develop`
  at `16e98fe`. Cold start verified against `state.ps1`, not a paste.
- 2026-09-21 — Tests written first and watched red: 20 failed, 1 passed, with the
  loader absent (`tests/evidence/01-red-before-implementation.txt`).
- 2026-09-21 — The red run exposed two defects in the tests themselves, both of which
  would have shipped a guard that could not fail:
  1. `git grep` / `git check-ignore` exit 1 for "no match" — the passing case — and
     `$PSNativeCommandUseErrorActionPreference` turns that into a throw, so the secret
     scan failed on a clean tree. Exit codes are now handled as data.
  2. The private-key pattern starts with `-----`, which git reads as options: exit 129,
     nothing scanned, and a bare `if git grep` reads that as clean. Test and CI guard
     both pass it with `-e` now and treat any exit but 0 or 1 as a failed scan.
  A third, smaller one: PowerShell bound a loose `-e` as an abbreviation of
  `-ErrorAction`, so the pattern never reached git. Git args go in as one array.
- 2026-09-21 — Implementation landed, 24 tests green
  (`tests/evidence/02-green-after-implementation.txt`).
- 2026-09-21 — **Six** planted defects, each driving its own test red, each restored
  from git in a `finally` (`tests/evidence/03-planted-twins.txt`): ignore rule dropped;
  loader printing values; `-Check` setting anyway; `.env.example` dropping a required
  variable; `-Require` not throwing; the scan losing `-e`. Tree verified clean after
  restore. A seventh twin runs inside the suite itself — a planted token in a throwaway
  clone, proving the scan finds one.
- 2026-09-21 — CI guard added, first in the job. `docker run --env-file` documented.
  `secret-hygiene` skill written. Pushed; PR opened into `develop`. Not merged.

## Report block

```
HEAD local:        <sha> feature/env-local
origin/main:       7cb86c5
origin/develop:    16e98fe
Working tree:      clean
Plan updated:      yes
Annotated tag:     none (until GO)
Merged:            no
Pushed:            yes
Committed:         yes
```

## Jerry action required

Jerry, click <PR link>, then Merge.
