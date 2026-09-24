# Decisions

Decisions that change what this repository keeps, and why. Each one points at the forensic record
that carries its evidence. Newest first.

## 2026-09-24 - Public hygiene: forensic records keep what they say

**Context.** The repository is public. I12 PR 1 scanned every tracked file at `e195e49`, including
`.continuity/`, for local user paths, email addresses, tokens or private keys, and the name of the
private origin repository that several scripts were copied from. The scan found no user paths and no
tokens or keys. It found one email address and 36 occurrences of the private repository's name in live
files, all edited. `tests/PublicHygiene.Tests.ps1` now fails on any of the four in a tracked file
outside `.continuity/`.

**Decision.** Hits inside forensic records are **not** edited. A forensic record's `self` is a sha256
over its own bytes and the next record's `prev` points at it. Editing one word breaks every link after
it. Rewriting the chain to repair that would destroy the only property the chain has. The records stay
exactly as written, and are listed here instead:

| seq | subject | what it carries |
|---|---|---|
| 1 | `claude-agent-images-birth` | the private origin repository's name, once |
| 4 | `<name>-path-coupling-to-core` (the subject begins with the name) | the name, twice: in the subject and in the evidence |
| 8 | `prebirth-tests-retired` | the name, once |
| 12 | `tidy-before-promotion-six-items` | the name, twice |
| 16 | `repo-public-by-decision` | the name, once |
| 17 | `promotion-develop-to-main-994adf8` | the name, twice |
| 23 | `promotion-develop-to-main-249752d` | the name, once |
| 29 | `public-hygiene` | the name, once, in the decision that opened this pass |
| 19 | `stale-premises-five-items` | a personal address written as `<user> at gmail`, not in address form, so the scan's email pattern did not match it. Listed because it is the same disclosure. |

A finding record at seq 30, `public-hygiene-records-not-edited`, points at this list.

**Not clearable without a history rewrite, and not attempted:** git commit metadata carries personal
author addresses (for example `eefebd8`), and earlier blobs of `END_GOAL.md` hold the address that
line 291 named until this pass. Neither is a tracked file at the tip. This repository never rewrites
history. Stopping the forward leak is an identity setting, and it is Jerry's to change.

**Licence.** MIT, JerryBalmer1, 2026, in `LICENSE`, stated in one line of `README.md`.
