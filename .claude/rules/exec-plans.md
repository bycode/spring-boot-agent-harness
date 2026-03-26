---
paths:
  - "docs/exec-plans/**"
---

# Execution plans

## Epics

When work spans multiple plans, persist an epic file BEFORE creating any child plans.

Named `EPIC-NNNN-topic.md`. Use next available sequence number (glob both `active/` and `completed/` to find the highest existing `EPIC-NNNN`).

### Required sections

- Context (why this epic exists)
- Key architectural decisions (table: Decision, Choice, Rationale)
- Execution plans (list of child PLANs with dependencies and parallelism)
- Definition of done
- Tech debt introduced

### Ordering constraint

1. Persist the EPIC file to `docs/exec-plans/active/` first.
2. Then create child PLAN files (they reference the epic).
3. When all child plans are completed, move the EPIC to `docs/exec-plans/completed/`.

## Plan file format

Named `PLAN-NNNN-topic.md`. Use next available sequence number.

**MANDATORY**: Before assigning a plan number, glob `docs/exec-plans/active/` and `docs/exec-plans/completed/` to find the highest existing `PLAN-NNNN` number and increment by one. Never assume the next number — always check.

### Required sections

- Goal
- Non-goals
- Approach
- Steps (checklist -- mark `- [x]` as completed)
- Decision log (append-only -- record every non-trivial choice and why)
- Risks & mitigations
- Definition of done
- Tech debt introduced (list workarounds/deferred work, or "None")

## Execution discipline

While executing a plan, treat the plan file as a living document:

1. **Before starting a step**: mark it `- [~]` (in progress).
2. **After completing a step**: mark it `- [x]`.
3. **Decision log**: append a row immediately when making a non-trivial choice (library version, alternative approach, workaround). Do not batch these for later.
4. **If a step is skipped or changed**: update the step text and add a decision log entry explaining why.

## Finalization

When all steps are done:

1. Verify every step is `- [x]` or explicitly marked skipped with rationale.
2. Check decision log for tech debt — append to `docs/exec-plans/TECH-DEBT-TRACKER.md` if any.
3. Set front-matter `status: completed`.
4. Move file from `docs/exec-plans/active/` to `docs/exec-plans/completed/`.
