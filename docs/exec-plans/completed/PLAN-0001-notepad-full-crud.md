---
status: completed
---

# PLAN-0001: Notepad Full CRUD

## Goal
- Extend the notepad reference module with list (paginated), update (PUT), and delete endpoints
- Add `updatedAt` timestamp to demonstrate update tracking
- Showcase all common REST/CRUD patterns for template consumers

## Non-goals
- PATCH (partial update) support
- Search/filtering
- Tags or relationships
- Bulk operations

## Approach
- Follow existing vertical slice pattern exactly (domain -> port -> use case -> facade -> persistence -> REST)
- One use case per operation, framework-free domain, port-based isolation
- Domain `Page<T>` record instead of Spring's `Page` to keep public API framework-free
- Non-idempotent DELETE (404 on missing) for template clarity

## Steps
- [x] Create `V3__add_updated_at_to_notes.sql` migration
- [x] Update `Note` record with `updatedAt`, create `Page<T>` record, extend `NotepadAPI`
- [x] Extend `NotePersistencePort` with `findAll`, `existsById`, `deleteById`
- [x] Create `ListNotesUseCase`, `UpdateNoteUseCase`, `DeleteNoteUseCase`
- [x] Update `NotepadFacade` and `NotepadModuleConfiguration` wiring
- [x] Update `NoteEntity`, `NoteRepository`, `NoteRepositoryAdapter`
- [x] Update `CreateNoteUseCase` for 5-field Note constructor
- [x] Create `UpdateNoteRequestDTO`, `NotePageResponseDTO`; update `NoteResponseDTO`
- [x] Add list/update/delete endpoints to `NoteController`
- [x] Update `InMemoryNotePersistence` test fake
- [x] Update existing tests for 5-field Note constructor
- [x] Add new unit tests (ListNotesUseCase, UpdateNoteUseCase, DeleteNoteUseCase)
- [x] Add new controller slice tests (list, update, delete)
- [x] Add new repository adapter slice tests (findAll, delete, existsById, update)
- [x] Add new module tests (list, update, delete)
- [x] Add new integration tests (list, update, delete)
- [x] Update module contract (`.claude/rules/modules/notepad.md`)
- [x] Generate OpenAPI spec and run `full-check`

## Contract updates (if this plan changes a module's REST boundary)
- [x] Module contract consumer surface reviewed/updated
- [x] OpenAPI annotations match contract

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Spring Data JDBC `save()` with non-null `@Id` does UPDATE | `UpdateNoteUseCase` verifies existence via `findById` first |
| `Page` name collision with Spring's `Page` | Domain `Page` in `nl.jinsoo.template.notepad`; use FQN for Spring's in adapter |
| NullAway on new `@Nullable` fields | `@NullMarked` already on all packages; just add `@Nullable` where needed |

## Definition of done
- [x] Audit agent passes (spawn `audit` agent to verify rule compliance)
- [x] `scripts/harness/full-check` passes
- [x] All 5 CRUD endpoints work end-to-end
- [x] Test coverage at all 4 tiers (unit, slice, module, integration)

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-03-26 | Add `updatedAt` to `Note` | User confirmed; demonstrates update-tracking pattern |
| 2026-03-26 | Domain `Page<T>` instead of Spring `Page` | Keeps public API framework-free per modulith rules |
| 2026-03-26 | Non-idempotent DELETE (404 on missing) | More informative for template consumers than silent 204 |
| 2026-03-26 | Default sort `createdAt DESC` on list | Newest-first is the most common UX expectation |
| 2026-03-26 | PUT only, no PATCH | User chose minimal scope; PATCH adds null-handling complexity |

## Tech debt introduced
- None.
