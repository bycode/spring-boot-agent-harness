---
status: completed

---

# PLAN-0002: harness findings fixes

## Goal
Fix verified issues in init-template, new-module, and documentation that leave generated repos broken or inconsistent.

## Non-goals
- ArchUnit enforcement of @Transactional(readOnly) — naming heuristics add friction for marginal value
- Changing CI to use scripts/harness/mvn — CI targets log output, not agents
- Rebinding PMD/SpotBugs to a different Maven phase

## Approach
Four independent fixes, each a single commit candidate:
1. init-template: fix broken migration chain + stale artifacts + agent memory cleanup
2. new-module: fix generated validation commands (./mvnw -> scripts/harness/mvn, IT command convention)
3. CLAUDE.md: fix fast-check description to match reality (includes static analysis)
4. README.md: align commands with scripts/harness/mvn convention

## Steps
- [x] Step 1: Fix init-template — expand notepad removal (V3 migration, openapi.json reset, agent memory), upgrade verification gate from compile to full-check
- [x] Step 2: Fix new-module — replace ./mvnw with scripts/harness/mvn in generated contracts, fix IT command to use verify + -Dit.test + *IT suffix
- [x] Step 3: Fix CLAUDE.md fast-check description — "compile + static analysis + doc-lint"
- [x] Step 4: Fix README.md — replace ./mvnw with scripts/harness/mvn in Development section, fix fast-check description

## Contract updates (if this plan changes a module's REST boundary)
- N/A — no REST changes

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| init-template full-check gate requires Docker at template init time | Acceptable — Docker is already a prerequisite; document in init-template usage |

## Definition of done
- [ ] Every step that touched production code includes its tests (no deferred test plans)
- [ ] `scripts/harness/full-check` passes
- [ ] Dry-run or manual verification that init-template on a /tmp copy produces a startable repo

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-04-09 | Drop readOnly ArchUnit rule | Naming heuristic would add false positives for a performance hint, not a correctness issue |
| 2026-04-09 | Keep CI on ./mvnw | CI logs target humans, not agents — wrapper's minimal output isn't needed there |
| 2026-04-09 | Choose Option A for fast-check (fix docs, not behavior) | PMD+SpotBugs on compile is deliberate early feedback; the problem is the label |

## Tech debt introduced
- None.
