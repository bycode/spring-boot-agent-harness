---
paths:
  - "docs/exec-plans/**"
  - "src/**"
---

# Execution plans

Non-trivial work requires an exec plan BEFORE writing code. See `docs/PLANS.md` for full guidance.

## When to create a plan

Create a `PLAN-NNNN-topic.md` before editing when:
- the change spans multiple files
- the change is architectural
- the change needs tracked decisions, risks, or staged execution
- the work would be hard to resume from code diff alone

Create an `EPIC-NNNN-topic.md` first when the work spans multiple plans or is cross-cutting.

## Creating plans

Always use the scaffold script — never create plan files manually:

```bash
scripts/harness/new-exec-plan plan <topic-slug>          # standalone plan
scripts/harness/new-exec-plan plan <topic-slug> EPIC-XXXX # plan under an epic
scripts/harness/new-exec-plan epic <topic-slug>           # new epic
```

Plan mode's internal plan file is supplementary — the exec plan in `docs/exec-plans/active/` is the durable record.

## Completion checklist

When ALL steps in a plan's checklist are done AND the definition-of-done criteria pass:

1. Mark every `- [ ]` as `- [x]` in the plan file
2. **Move the plan file** from `docs/exec-plans/active/` to `docs/exec-plans/completed/`
3. Commit the move as part of the final commit (or as a dedicated commit)

The plan is NOT complete until the file lives in `completed/`. Marking checkboxes without moving the file is incomplete work.

## When committing planned work

Before creating commits for work tracked by an exec plan, verify:
- Is there an active plan in `docs/exec-plans/active/` for this work?
- If yes, has every step been completed?
- If yes, move the plan to `completed/` and include the move in the commit

Never commit planned work while the plan still sits in `active/`.

## Working rules

- Persist the approved plan before editing code.
- Keep checklist state current as work progresses.
- Append decision-log entries when you make a real trade-off.
- Record tech debt when you knowingly leave a compromise behind.
