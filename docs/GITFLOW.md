# Git-flow for claude.agent.images

This repo follows a stripped-down git-flow. The leash is a job tool, not a product — the branching model exists so the demo stays reproducible and the experiment results don't get lost in a pile of commits on main.

## Branches

| Branch | Purpose | Who writes | Merges into |
| --- | --- | --- | --- |
| `main` | Releases only. Every commit on main is a tagged, buildable image. | Nobody directly. Only via PR from `release/*` or `hotfix/*`. | — |
| `develop` | Integration branch. Everything lands here first. | PRs from `feature/*`. | `release/*`, `main` (via release) |
| `feature/<name>` | One piece of work. Branched off `develop`, PR'd back into `develop`. | You. | `develop` |
| `release/<x.y.z>` | Freeze + polish before a tag. Branched off `develop`. | You. | `main` + back into `develop` |
| `hotfix/<name>` | Emergency fix to a tagged release. Branched off `main`. | You. | `main` + back into `develop` |

## Rules

1. **No direct pushes to `main`.** If you need to fix something on a release, use `hotfix/*`.
2. **No direct pushes to `develop`.** Feature work goes through a PR so there's a record of *why* it changed.
3. **One feature = one branch = one PR.** If the work splits, split the branch.
4. **Tag every image you ship.** `git tag v0.1.0` on the `main` commit that produced it. The tag is the digest's human name.
5. **CI must be green before merge.** The workflow in `.github/workflows/ci.yml` validates the Dockerfile, shell scripts, and PowerShell syntax. It does *not* run the sentinel experiment — that stays local until it passes, then it gets documented in the PR.

## Why this exists

The sentinel experiment (interactive + headless + negative control) is the only thing that decides if this repo is a job tool or a corpse. Git-flow keeps that experiment's result attached to a specific commit instead of floating in `main`'s history where nobody can find it when the demo fails in front of a hiring manager.

## Current state

- `main` @ 8f7446d — initial scaffold (Dockerfile, managed-settings, sentinel hook, entrypoint).
- `develop` created from that commit.
- This branch (`feature/git-flow-init`) adds the docs + CI skeleton. Merge to `develop` first.

## Plans are the source of truth

Every feature branch carries a plan file in docs/plans/. The active plan is
docs/plans/ACTIVE.md. Read it before editing; update its Progress section after
every change; archive it to docs/plans/archive/ on merge.

No plan file means no commit. Annotated tags mark completed work; lightweight
tags are forbidden. Tag message must name the plan, branch, PR, CI status, and
outcome. See AGENTS.md for the full rules.

Start at [`.ALLAGENTS.md`](../.ALLAGENTS.md) — the source of truth every agent reads first — and let
[`scripts/snake.ps1`](../scripts/snake.ps1) check the plan for you: `pwsh -NoProfile -File scripts/snake.ps1 -DryRun`.
