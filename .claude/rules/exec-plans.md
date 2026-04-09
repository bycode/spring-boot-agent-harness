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

## Creating plans and epics

**MANDATORY**: Always use `scripts/harness/new-exec-plan` to create plan and epic files. Never create them by hand.

```bash
# Create a plan
scripts/harness/new-exec-plan plan <topic-slug>

# Create a plan under an epic
scripts/harness/new-exec-plan plan <topic-slug> EPIC-XXXX

# Create an epic
scripts/harness/new-exec-plan epic <topic-slug>

# Dry run (preview filename without creating)
scripts/harness/new-exec-plan --dry-run plan <topic-slug>
```

The script auto-assigns the next sequence number and generates a template with every required section. Fill in the template — do not skip sections, do not restructure the file.

## Plan size limit

**Maximum 12 steps per plan.** If planning produces more than 12 steps, split the remaining steps into a follow-up plan. This prevents quality degradation during execution: agents lose coherence on long plans as context accumulates.

When planning produces >12 steps:
1. Put the first ≤12 steps in the current plan.
2. Create a follow-up plan for the remaining steps (`scripts/harness/new-exec-plan plan <topic-slug>`).
3. Reference the follow-up in the current plan's approach section so the dependency is clear.

## Plan file format

Named `PLAN-NNNN-topic.md`. Sequence number is assigned by the script.

### Required sections

- Goal
- Non-goals
- Approach
- Steps (checklist — see "Session blocks" below for structuring steps)
- Decision log (append-only — record every non-trivial choice and why)
- Risks & mitigations
- Definition of done
- Tech debt introduced (list workarounds/deferred work, or "None")
- Execution notes (append-only — see "Execution notes" below)

## Session blocks

For plans with more than 5 steps, group steps into **session blocks** of 3–5 steps each. Each block is designed to fit comfortably within a single agent context window.

```markdown
## Steps

### Block 1 — Domain layer
Context: none (first block)
- [ ] Migration V3__add_updated_at
- [ ] Domain record updates (Note with updatedAt)
- [ ] Port interface extensions (update, delete, list)

### Block 2 — Use cases & wiring
Context: Note record has updatedAt; ports include update/delete/list
- [ ] Use case implementations
- [ ] Facade wiring and configuration
- [ ] Unit tests for use cases

### Block 3 — Persistence & REST
Context: Facade exposes list/update/delete; Note has updatedAt
- [ ] Entity, repository, persistence adapter
- [ ] DTOs, controller, exception handler
- [ ] Slice + integration tests
```

### Block rules

1. **`Context:` line is mandatory** for every block after the first. It lists only what the agent needs from prior blocks — not everything, just what's relevant to *these* steps. Keep it to 1–2 lines.
2. **Tests belong in the block that introduces the code**, not a separate block.
3. **A fresh session should start between blocks.** The agent completing a block should write execution notes (see below), then the next block can be picked up in a new session or delegated to a sub-agent.
4. Plans with ≤5 steps do not need blocks — a flat checklist is fine.

### Sub-agent delegation for blocks

For plans with 3+ blocks, prefer delegating each block to a sub-agent rather than executing everything in one session. The orchestrating agent:

1. Reads the plan file and identifies the next incomplete block.
2. Spawns a sub-agent with a prompt containing: the block's context line, its steps, relevant file paths, and the plan's non-goals.
3. After the sub-agent completes, the orchestrator verifies the block's steps, writes execution notes, and moves to the next block.

This keeps each execution context focused and prevents quality degradation on later steps.

## Tests live with the code

Tests are not a separate phase — they ship in the same plan as the production code they cover.

### Rules

1. **Same plan, not later.** Every plan step that introduces or modifies production code must include the tests for that code. Never create a dedicated "write tests" plan.
2. **Pass before proceeding.** Tests for a step must pass before marking the step `- [x]` and moving to the next step.
3. **Existing code without tests.** If you edit production code that lacks tests, add tests in the same plan.
4. **Test tier placement in multi-plan epics:**

   | Test tier | Where it lives |
   |-----------|---------------|
   | Unit / slice / module tests | Same plan as the production code |
   | Integration tests for endpoints introduced in the plan | Same plan — update existing `*IT` if one exists |
   | Cross-module integration tests (depend on work from multiple plans) | Explicit plan in the epic, listed upfront — scoped only to cross-cutting ITs |

5. **Epic planning.** When an epic requires cross-module integration tests, include that plan in the epic's execution plan list from the start — not as an afterthought.

## Execution discipline

While executing a plan, treat the plan file as a living document:

1. **Before starting a step**: mark it `- [~]` (in progress).
2. **After completing a step**: mark it `- [x]`.
3. **Decision log**: append a row immediately when making a non-trivial choice (library version, alternative approach, workaround). Do not batch these for later.
4. **If a step is skipped or changed**: update the step text and add a decision log entry explaining why.
5. **After completing a block**: append to `## Execution notes` before starting the next block (see below).

## Execution notes

The `## Execution notes` section captures discoveries made during execution that affect future steps. This is what makes plans resumable across context resets — a fresh session reads the execution notes instead of re-deriving insights from code.

### Rules

1. **Append after each block** (or after every 2–3 steps if not using blocks).
2. **Write targeted, actionable notes** — not a journal. The test: "Would a fresh session waste time rediscovering this?"
3. **Format**: date, block/step reference, the finding.

### Example

```markdown
## Execution notes

- 2026-04-09 (Block 1): NoteEntity needs @Version for optimistic locking — affects update test assertions in Block 3
- 2026-04-09 (Block 2): InMemoryNotePersistence.update() must check existence first — Spring Data JDBC save() upserts silently
```

## Finalization

When all steps are done:

1. Verify every step is `- [x]` or explicitly marked skipped with rationale.
2. Check decision log for tech debt — append to `docs/exec-plans/TECH-DEBT-TRACKER.md` if any.
3. Set front-matter `status: completed`.
4. Move file from `docs/exec-plans/active/` to `docs/exec-plans/completed/`.
