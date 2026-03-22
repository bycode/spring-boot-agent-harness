# Planning Guide

This repository treats plans as durable execution artifacts, not disposable chat output. For non-trivial work, planning belongs in versioned markdown under `docs/exec-plans/`.

## Where Plans Live
- Active work: [docs/exec-plans/active](exec-plans/active)
- Completed work: [docs/exec-plans/completed](exec-plans/completed)

## When To Create An Epic
Create an `EPIC-NNNN-topic.md` first when:
- the work spans multiple plans
- the work is cross-cutting across architecture, tooling, docs, and code
- you need a single parent record for sequencing and definition of done

An epic should contain:
- Context
- Key architectural decisions
- Execution plans
- Definition of done
- Tech debt introduced

## When To Create A Plan
Create a `PLAN-NNNN-topic.md` before editing when:
- the change spans multiple files
- the change is architectural
- the change needs tracked decisions, risks, or staged execution
- the work would be hard to resume from code diff alone

Plans should stay narrower than epics. A plan is the unit of execution; an epic is the unit of coordination.

## Plan Structure
A plan should contain:
- Goal
- Non-goals
- Approach
- Steps
- Risks & mitigations
- Definition of done
- Decision log
- Tech debt introduced

Steps should be checklists that can move from planned to completed as the work progresses.

## Working Rules
- Persist the approved plan before editing.
- Keep checklist state current as work progresses.
- Append decision-log entries when you make a real trade-off, not only at the end.
- Record tech debt when you knowingly leave a compromise behind.
- Move completed plans from `active/` to `completed/` once the work is actually finished.

## Completion Standard
The current repo standard is:
- the `audit` agent passes (verifies compliance with `.claude/rules/`)
- the appropriate tests for the change are present and passing
- `scripts/harness/full-check` passes (build + tests + doc-lint + smoke-startup + openapi-drift)

If the work changes architecture, module ownership, validation behavior, or repo process, update the related docs as part of the same plan.

## Relationship To Other Durable Records
- Use [LEARNINGS.md](learnings/LEARNINGS.md) for reusable gotchas discovered during execution.
- Use ADRs and design docs when a decision needs long-lived architectural rationale beyond a single execution plan.
