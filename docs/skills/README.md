# Skills

Reusable capabilities. One `.md` per skill. Frontmatter required:

```
name, triggers, inputs, outputs, do-not, learned-from
```

The snake reads this index before executing a plan. A plan that names a skill the
snake does not have is a **STOP**, not a warning — `scripts/snake.ps1` exits 1
and reports the missing file.

## Index

- [plan-authoring.md](plan-authoring.md) — how to write a plan that actually executes
- [business-outcomes.md](business-outcomes.md) — OKRs, milestones, "done" definitions
- [session-handoff.md](session-handoff.md) — handing off to the next chat without carrying stale state

## Rules

- Skills are written DURING execution, not after. If you learned it while running
  a plan, write it before the plan closes.
- A skill that removes friction stays. One that adds friction dies.
- Kaizen: every cycle, one skill gets sharper or one gets deleted. A skills
  directory that only grows is a filing cabinet, not muscle.
- `_template.md` and this `README.md` are not skills. The snake ignores them when
  resolving a plan's `## Skills referenced` list.

## Naming

The name in frontmatter matches the filename without `.md`. A plan references a
skill by that bare name — `plan-authoring`, not `docs/skills/plan-authoring.md`.
Both forms resolve, but the bare name is the convention.
