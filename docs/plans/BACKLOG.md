# Backlog

One line per candidate plan, in execution order. `scripts/snake.ps1 -NextPlan` takes the
**first unchecked item** and drafts `docs/plans/ACTIVE.md` from `_template.md`, so the order
here is the order work happens. Check an item off when its PR is open, not when it merges —
otherwise the snake drafts it again.

The full prompt for each numbered item lives in `docs/plans/backlog/`. Those files are the
intent as Jerry and Fable wrote it; they are **not** plans. A plan is written from one of
them into `docs/plans/<date>-<slug>.md` per `docs/skills/plan-authoring.md`, with its Context
verified against `scripts/state.ps1` rather than copied from the prompt.

## Queue

- [x] 00 — .env.local: credentials outside the tree, loaded in one line
      prompt: docs/plans/backlog/00-env-local.md
      plan:   docs/plans/2026-09-21-env-local.md — executed, PR #6, awaiting merge
- [ ] 01 — container proof: vendor the siblings, .build.ps1, the parking rule
      prompt: docs/plans/backlog/01-container-proof.md
      the big one. Makes the image real and proves the deny gate from inside a container.
- [ ] reconcile main and develop — they are two incompatible layouts
      Not a numbered plan; found 2026-09-21 while diagnosing PR #5. origin/main carries
      exactly one commit develop does not, 7cb86c5, pushed directly to main against
      AGENTS.md's own branch rules and authored "Jerry Balmer" through the GitHub App.
      It is a parallel repo: .build.ps1 + build/tasks/*, images/developer/* (a second
      Dockerfile, entrypoint, sentinel hook and managed-settings), plans/ and skills/
      rather than docs/plans/ and docs/skills/, schemas/plan.schema.json,
      tests/plan.failfirst.ps1, and a different AGENTS.md. main has NO
      .github/workflows/ci.yml at all, so no guard — trailers, tags, secrets — has ever
      run there.
      Merging PR #5 as-is unions both layouts: two Dockerfiles, two sentinel hooks, two
      plan systems, two skill systems, and one AGENTS.md resolved by hand. That breaks
      .ALLAGENTS.md's "one skill system". The AGENTS.md conflict is add/add.
      Note main's build is designed red: Plan.Check throws because src/PlanValidator.ps1
      does not exist, and Test.FailFirst throws unless its own test fails. Scaffolding,
      not a working build.
      Jerry's call 2026-09-21: leave PR #5 open, merge #6 only, proceed with 01. Plan 01
      writes .build.ps1 in main's Invoke-Build shape (root .build.ps1 dispatching to
      build/tasks/*.build.ps1) so this reconciliation is a merge, not a third rewrite.
- [ ] 02 — agents and skills
      prompt: docs/plans/backlog/02-agents-and-skills.md
      01 goes first: .agents/ and the vault are worth nothing until the container is real.
- [ ] 03 — pretty obsidian skills
      prompt: docs/plans/backlog/03-pretty-obsidian-skills.md
- [ ] Pro upgrade — GitHub Pro, so rulesets and branch protection exist at all
      Not a code plan; Jerry's account change. Probed 2026-09-21: all six repos returned
      403 "Upgrade to GitHub Pro or make this repository public" on /rulesets and on
      /branches/main/protection. On Free + private there is no branch protection to
      configure, so 04 cannot be applied or tested. Prove it with the probe in
      docs/plans/backlog/04-accountability-iac.md before writing a line of rulesets.tf.
- [ ] 04 — accountability as code: terraform, rulesets, signing
      prompt: docs/plans/backlog/04-accountability-iac.md
      Blocked on the Pro upgrade above. Also needs .build.ps1, which 01 delivers.
- [ ] archive and tag the operating-protocol plan
      docs/plans/2026-09-20-operating-protocol.md merged in PR #4 and was never archived
      or tagged. That is row 7 of AFTER-CLAUDE-COMMITS.md:
      `pwsh -NoProfile -File scripts/snake.ps1 -Archive -Go -Pr 4 -Ci green`
      Housekeeping, not a feature. Can run at any point.

## Not queued

Nothing yet. An idea that is not in the list above is not queued, however often it comes up
in a chat — write it here or it does not exist.
