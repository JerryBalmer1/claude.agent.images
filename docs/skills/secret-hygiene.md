---
name: secret-hygiene
triggers: Any plan that needs a token, key, PAT, connection string or password. Any time you are about to write a credential into a file, a workflow, a tfvars, an image layer, or a chat message. Any time you catch yourself about to echo a variable to prove it loaded.
inputs: The credential's name, who reads it, where the human creates it, and its expiry.
outputs: A committed `.env.example` documenting the variable, a gitignored `.env.local` holding the value, a loader that sets `$env:` without printing values, and a CI guard that scans tracked files.
do-not: Do not print, log, echo or interpolate a credential value — not even truncated, not even "just to check". Do not commit a real value to any tracked file. Do not bake a credential into a Docker layer. Do not ask a human to paste a token into a chat.
learned-from: 2026-09-21-env-local (the plan that built `scripts/env.ps1`); the `-Check` mode and the length-only report exist because the first instinct in every session is to echo the variable to prove the load worked.
---

# secret-hygiene

## When to use

Before the first line of any plan that touches a credential. The pattern below is
cheap to follow up front and expensive to retrofit: once a token is in git history,
rotating it is the only real fix, and history rewriting is forbidden here
(`AGENTS.md`, no force-push).

## The shape

Three files, always in this order. The order matters — the ignore rule exists
**before** the file it protects.

1. **`.gitignore` first.** Add the ignore rule and verify it with
   `git check-ignore -q <file>` before creating the file it covers. A file created
   before its ignore rule can be staged by a careless `git add -A` in the window
   between the two.
2. **`.env.example`, committed.** One variable per line, every line commented with
   what it is, who reads it, where the human creates it, and what permissions it
   needs. Values are empty or non-secret defaults. This file is the documentation;
   it is also what a test greps to prove no real token leaked into it.
3. **`.env.local`, never committed.** The human pastes real values. An agent creates
   it empty and never reads a value out of it.

Then a loader that sets `$env:NAME` and a CI guard that scans tracked files.

## The reporting rule

A loader reports **that** a variable is set, never **what** it is set to:

```
GITHUB_TOKEN                   set (len 93)
TF_VAR_owner                   set (len 12)
TF_VAR_mirror_owner            EMPTY
```

Length is enough to tell a pasted token from a truncated one, and leaks nothing
useful. There is no "just show the first four characters" exception: a prefix
identifies the token type and narrows a brute force, and the habit is what kills
you on the day the output goes into a CI log.

## Verify it, do not trust it

Every claim in this skill has a command behind it. A plan using this pattern carries
all four:

```
git check-ignore -v .env.local                       # exit 0 = ignored
pwsh -NoProfile -File scripts/env.ps1 -Check         # names and lengths, no values
git grep -nE 'ghp_[A-Za-z0-9]{20,}' -- .             # exit 1 = clean
pwsh -NoProfile -File tests/run.ps1                  # the planted twins
```

## Plant the twin

A test that has never failed is decoration. For each guarantee, break it on purpose
and watch the matching test go red before you rely on it:

| Guarantee | Planted defect | Test that must go red |
| --- | --- | --- |
| `.env.local` is ignored | remove the line from a temp `.gitignore` | `check-ignore` test |
| the loader never leaks | make the loader `Write-Host` the value | the no-leak test |
| the tree has no secrets | write `ghp_<fake>` into a tracked file in a temp clone | the secret-scan test |

Restore from git, not by retyping — `git checkout -- <path>` — and re-run green.
A probe that mutates a file in place without a `try/finally` will leave the repo
broken the first time it throws.

## Containers

`docker run --env-file .env.local ...`. Never `ENV GITHUB_TOKEN=` in a Dockerfile,
never `--build-arg` for a secret: both persist in the image layers and survive
`docker history` for anyone who pulls the image.

## Do not

- Never ask a human to paste a token into a chat. A token in a chat log is burned and
  must be revoked, whoever it was sent to.
- Never write a credential into a plan file, a commit body, a test fixture, or a
  workflow file.
- Never weaken the CI guard to make a build pass. If the guard fires, the tree is
  wrong, not the guard (`FLOW.md` §9).
