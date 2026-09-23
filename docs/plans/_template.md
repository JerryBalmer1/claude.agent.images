# Plan: <title>

Date: YYYY-MM-DD
Branch: feature/<slug>
PR: (link, filled on open)
Status: draft | executing | done | abandoned

## Goal

<one paragraph: what "done" looks like>

## Context

<what exists, what broke, why now — verified with commands, not remembered>

<compliance checklist: secrets / PII / PCI / network egress / blast radius.
 "N/A" is a valid answer; silence is not. See docs/skills/plan-authoring.md>

## Business outcome

<the OKR, milestone, revenue or risk this serves, with a measure.
 "Done" means this moved, not that code was written.
 The snake refuses to archive a plan that leaves this empty.
 See docs/skills/business-outcomes.md>

## Skills referenced

<bare skill names, one per line. Each must exist as docs/skills/<name>.md
 or the snake stops.>

- plan-authoring
- business-outcomes

## Allow-list (only these paths may change)

-

## Do-not-touch

-

## Steps

1.
2.

## Verify (local, no commit)

```
<commands an agent runs to prove the work, with no commit>
```

## Progress

<updated after every change; never left stale>

## Report block

```
HEAD local:        <sha> <branch>
origin/main:       <sha>
origin/develop:    <sha>
Working tree:      clean | dirty
Plan updated:      yes | no
Annotated tag:     none (until GO)
Merged:            no
Pushed:            no
Committed:         no
```

## Jerry action required

Jerry, click <PR link>, then Merge.

<!-- If there is no human action, replace the line above with:
     Jerry action required: none — agent may proceed on GO.
     Never omit this header. -->
