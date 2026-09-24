# Findings

Defects found in this repository: what they did, what caused them, and what catches them now. Each
one points at its forensic record and, where one exists, the decision in `DECISIONS.md`. Newest first.

## I13-F1 - 23b1db9 rewrote 658 lines of END_GOAL.md where one was meant

- **What it did.** Every `a` in `END_GOAL.md` became a space and every backtick became `j`, across the
  header and every section older than `23b1db9`. It rode through #17 to #20 because `Goal.Update` reads
  only the newest section. Found and repaired in I12 (#21, forensic seq 38, confession).
- **Cause.** An inline edit command held its one replacement as `@( @('<old>', '<new>') )`. `@()`
  unrolls the inner array, so the loop walked two strings and indexed characters, which gave
  `Replace('<backtick>', 'j')` and then `Replace('a', ' ')`.
- **Reproduced.** The exact entry and loop, on `23b1db9~1`'s blob `b017750`, give `23b1db9`'s blob
  `54901e2` byte for byte.
- **Caught now by.** `scripts/Edit-Text.ps1` refuses it at edit time: each old string must occur exactly
  once, and the declared line diff is checked before writing. `tests/ScriptedEdit.Tests.ps1` holds both
  the reproduction and the refusal. `tests/EndGoalIntegrity.Tests.ps1` (#21) catches damage to any
  section after the fact.
- **Sites in the tree using the pattern.** None. See the decision.
- **Records.** `DECISIONS.md` 2026-09-24, *23b1db9: a one-pair edit list unrolled into two one-character
  replacements*. Forensic chain seq 46, finding, `end-goal-23b1db9-root-cause`.
