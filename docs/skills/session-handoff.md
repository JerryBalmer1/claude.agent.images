---
name: session-handoff
triggers: Ending a session; writing a "next life" or "paste this into a new chat" block; starting a fresh session from a pasted block; any moment you are about to type a SHA, PR number or branch state by hand.
inputs: The live repo (via scripts/state.ps1), the active plan, whatever the outgoing session learned.
outputs: A handoff that contains no transcribed state — only pointers to files in the repo and the output of state.ps1.
do-not: Do not transcribe state into the handoff. Do not reference a file that does not exist. Do not put the protocol in the handoff instead of in the repo.
learned-from: 2026-09-20-operating-protocol. The predecessor handoff referenced two files that were never written, and its state block was wrong within six hours.
---

# session-handoff

## When to use

At the end of a session, and at the start of the next one. Also the moment you
notice yourself about to type `develop = 4d7ef09` into a chat message — that is
the exact keystroke this skill exists to prevent.

## The rule

**A handoff carries pointers and intent. It never carries state.**

State goes stale between writing the handoff and reading it. In this repo that
window has been as short as six hours, and it has cost a full reconcile cycle
twice. Anything a command can answer must be answered by the command, at read
time, not by a human at write time.

| Carry in the handoff | Get from the repo at read time |
|---|---|
| What we were trying to do | Branch names and SHAs |
| Decisions the human made | PR numbers and whether they merged |
| What is deliberately not done yet | CI status |
| Which files to read first | Whether the tree is clean |
| Open questions for the human | What the active plan says |

## Steps

1. **Check every file you reference actually exists.** The predecessor handoff
   opened with "paste this + FLOW.md + AFTER-CLAUDE-COMMITS.md" and neither
   file was in the repo. A handoff that fails on its first line is worse than
   none, because it burns the reader's trust before they reach the useful part.

   ```
   foreach ($f in 'FLOW.md', 'AFTER-CLAUDE-COMMITS.md', '.ALLAGENTS.md') {
       if (-not (Test-Path $f)) { Write-Host "HANDOFF REFERENCES A MISSING FILE: $f" }
   }
   ```

2. **Put the protocol in the repo, not in the handoff.** If the handoff explains
   a rule, that rule belongs in `FLOW.md` and the handoff should link to it.
   Prose that lives only in a chat paste dies with the chat.

3. **Replace the state block with a command.** The handoff says "run
   `scripts/state.ps1` and paste the output", never the output itself.

4. **Name the intent, not the mechanics.** "We are closing out the operating
   protocol plan; #4 is open and waiting on Jerry" is durable. "PR #4 is at
   `a1b2c3d`" is not.

5. **List open questions explicitly**, with who owns each one. An open question
   that reads like a statement gets executed instead of asked.

6. **Write the skill before the plan closes.** If this session learned a rule,
   it goes in `docs/skills/` now, not "next time".

## The handoff shape

```
READ FIRST (in the repo):
  .ALLAGENTS.md           - repo law
  FLOW.md                 - how work moves, which screen, precedence
  AFTER-CLAUDE-COMMITS.md - what to do with a Claude report
  docs/plans/ACTIVE.md    - what is authorised right now

LIVE STATE:
  Run: pwsh -NoProfile -File scripts/state.ps1
  Paste its output. It outranks anything written below.

WHERE WE ARE:
  <one paragraph of intent, no SHAs>

OPEN QUESTIONS FOR JERRY:
  1. <question> (owner: Jerry)

DELIBERATELY NOT DONE:
  - <thing>, because <reason>
```

## Verify

```
pwsh -NoProfile -File scripts/state.ps1
```

If the handoff you just wrote contains any value that also appears in that
output, delete it from the handoff. That is the test.

## Anti-patterns

- **The state block.** "Current state (do not redo): develop = 4d7ef09, PR #2
  OPEN." Wrong within hours. This is the one that keeps happening.
- **Referencing files that do not exist.** Check before you send.
- **Protocol living in the paste.** If it matters, it is a file. If it is not
  worth a file, it is not worth the handoff.
- **Burying a question in prose.** The next session will read it as context and
  act instead of asking.
- **"Do not redo" lists.** They go stale the same way state does. Point at
  `state.ps1` and the merged-PR list instead.
