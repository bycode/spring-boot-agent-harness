---
status: completed
---

# EPIC-0001: rule enforcement hooks

## Context
An enforcement audit of `.claude/rules/` (13 files) found that while build-time gates cover much of the ruleset — ArchUnit (modulith boundaries, `@Transactional` placement, constructor injection, no-JPA), NullAway (null safety), Spotless (formatting), JaCoCo (coverage), `ApplicationModules.verify()` (Modulith), and `check-openapi-drift` — a significant portion of every rule file remains documentation-only. Today only **two** hooks are wired in `settings.json`: `regression-first-reminder` (UserPromptSubmit) and `post-tool-hook` (PostToolUse). Documentation-only rules drift silently as sessions reset and context compresses; this epic promotes every clause flagged as "cheaply promotable" in the audit from prose into enforced gates (PostToolUse hooks, git pre-commit guards, or subprocess-output filtering).

Audit also surfaced three cleanup items: `scripts/harness/check-test-exists` and `scripts/harness/plan-progress-check` are dead standalones duplicated inline in `post-tool-hook`, and their comments still say "8-step limit" while the code checks `> 12`. These get consolidated here, because the new hooks will share the same shell library and the duplication is a divergence trap.

Rule clauses that are subjective (`var` usage, exception message wording), require semantic call-graph analysis (`NOT_SUPPORTED` for external calls, self-invocation bypass), or have better enforcement already (Spotless, ArchUnit, NullAway) are explicitly **out of scope** — listed in each child plan's "Non-goals".

## Key architectural decisions

| Decision | Choice | Rationale |
|---|---|---|
| Hook implementation language | Bash primarily; Python only where markdown table parsing is needed (module contract sync) | Matches existing harness style; no new runtime dependency |
| Hook architecture | Dispatcher pattern — `post-tool-hook` sources a shared library (`scripts/harness/lib/hook-checks.sh`) and calls check functions; each function returns a stdout chunk | Parse input JSON once; share tool_name/file_path across all checks; single place to own the JSON output encoding |
| Blocking vs non-blocking | Non-blocking (exit 0, inject `additionalContext`) for edit-time hooks; blocking (exit 1) for git pre-commit guards that prevent destructive actions (migration edit, jacoco-plugin edit) | Non-blocking keeps flow moving and matches existing `post-tool-hook`; blocking is reserved for actions that corrupt shared state |
| Split across multiple plans | One EPIC with 3 child PLANs | 12-step hard limit per `exec-plans.md` § "Plan size limit"; ~30 concrete steps needed |
| Hook test strategy | Fixture-based shell tests under `scripts/harness/tests/hooks/` driven by a new `scripts/harness/test-hooks` runner | Avoid bats/other framework dependency; shell-only matches the rest of the harness |
| Existing standalone scripts | Consolidate `check-test-exists` + `plan-progress-check` into the shared library; delete dead copies | Proven divergence risk: stale "8-step" comments show the standalones haven't been read in a long time |
| Secret scrubbing location | In `scripts/harness/run-cmd` wrapper, not as a Claude hook | `run-cmd` is the single path by which subprocess output reaches the agent; filtering there covers every Maven/bash invocation automatically |
| Per-rule enforcement pointers | Append an `Enforcement: scripts/harness/…` line to each rule clause that gets a hook | Makes it cheap for future audits to answer "is this rule enforced or docs-only?" without reading hook source |
| Scope of "cheaply promotable" | The 6 Tier-S + 6 Tier-A + 12 Tier-B + 3 cleanup items from the enforcement audit; excluded items (subjective style, semantic call-graph rules) are listed as Non-goals in each child plan | Hooks with high false-positive rates are worse than no hooks — they teach the agent to ignore `additionalContext` |

## Execution plans

| Plan | Topic | Dependencies | Parallelism |
|---|---|---|---|
| PLAN-0003 | regex-scanning-hooks | None — establishes shared library + dispatcher architecture and consolidates dead standalones | Must run first (foundational) |
| PLAN-0004 | plan-contract-discipline-hooks | PLAN-0003 (uses shared library + dispatcher + fixture runner) | Sequential after 0003 |
| PLAN-0005 | safety-guard-hooks | PLAN-0003 (uses shared library + fixture runner) | Can partially overlap with 0004 — touches different files (`run-cmd`, pom.xml guard, migration guard); merge conflicts unlikely |

## Definition of done
- [x] All three child PLANs (0003, 0004, 0005) moved to `docs/exec-plans/completed/`
- [x] `scripts/harness/full-check` passes on the final integrated result
- [x] `scripts/harness/test-hooks` passes (new fixture-based runner exists and is green — 81/81)
- [x] Every rule file flagged with a GAP in the audit now has at least one enforcement pointer next to the promoted clause. Note: PLAN-0003/PLAN-0004 used the `Nudge:` pointer convention; PLAN-0005 adopted `Enforcement:` for the three safety-guard rule files (security.md, persistence.md, jacoco-coverage.md). Both conventions are "look here to find the enforcing script" pointers — the format difference is logged under Tech debt.
- [x] No dead standalone hook scripts remain — verified: `scripts/harness/check-test-exists` and `scripts/harness/plan-progress-check` are deleted
- [x] Cross-plan audit agent spawned after PLAN-0005 reports no CRITICAL or HIGH findings against `.claude/rules/` — audit agent returned PASS with 0 findings across 7 claim-by-claim checks

## Tech debt introduced
- **Pointer format split between `Nudge:` (PLAN-0003/0004) and `Enforcement:` (PLAN-0005).** Both formats point the reader at the enforcing script, but a grep for one does not find the other. Unifying on a single format (probably `Enforcement:` since that's the one the epic's DoD originally specified) is a ~10-minute cleanup best rolled into PLAN-0007 (hook-checks refactor) or a small follow-up plan when convenient. Not load-bearing — existing enforcement is live and correct.
