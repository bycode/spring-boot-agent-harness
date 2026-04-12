---
paths:
  - "src/**/notepad/**"
---

# Notepad module contract

> Reference implementation — delete this module when starting real work.

## Purpose
Demonstrates the full vertical slice pattern: domain, use cases, persistence, REST, and tests at every tier.

## Complexity
standard

## Source of truth
Public API and allowed dependencies are declared in `package-info.java` via `@ApplicationModule(allowedDependencies = ...)` and enforced by `ApplicationModules.verify()` at test time. See https://docs.spring.io/spring-modulith/reference/fundamentals.html.

## Hidden packages (implementation details)

| Package | Contains |
|---------|----------|
| `internal/` | `NotepadFacade`, `CreateNoteUseCase`, `FindNoteByIdUseCase`, `ListNotesUseCase`, `UpdateNoteUseCase`, `DeleteNoteUseCase`, `NotePersistencePort`, `NotepadModuleConfiguration` |
| `persistence/` | `NoteEntity`, `NoteRepository`, `NoteRepositoryAdapter` |
| `rest/` | `NoteController`, `CreateNoteRequestDTO`, `UpdateNoteRequestDTO`, `NoteResponseDTO`, `NotePageResponseDTO`, `NoteExceptionHandler` |

## Cross-module communication
- **Direct API calls**: None — this module has no dependencies.
- **Events published**: None.
- **Events consumed**: None.

## Owned resources
- **Database table(s):** `notes` (`V2__create_notes_table.sql`, `V3__add_updated_at_to_notes.sql`)
- **REST endpoints:** `GET /api/notes`, `POST /api/notes`, `GET /api/notes/{id}`, `PUT /api/notes/{id}`, `DELETE /api/notes/{id}`
- **Events published:** None
- **Events consumed:** None

## Consumer surface

| Endpoint | Method | Request body | Success response | Error responses |
|----------|--------|-------------|-----------------|-----------------|
| `/api/notes` | GET | N/A (query: `page`, `size`) | 200 + `NotePageResponseDTO` | — |
| `/api/notes` | POST | `CreateNoteRequestDTO` (title, body) | 201 + `NoteResponseDTO` | 400 validation |
| `/api/notes/{id}` | GET | N/A | 200 + `NoteResponseDTO` | 404 not found |
| `/api/notes/{id}` | PUT | `UpdateNoteRequestDTO` (title, body) | 200 + `NoteResponseDTO` | 400 validation, 404 not found |
| `/api/notes/{id}` | DELETE | N/A | 204 No Content | 404 not found |

### Behavioral notes
- Create is not idempotent — each call creates a new note.
- `createdAt` is server-assigned; client cannot set it.
- List returns newest-first (by `createdAt` DESC). Default page size is 20, 0-based page index.
- Update is a full replace (PUT semantics) — both title and body are required.
- Update sets `updatedAt` to current server time; `createdAt` is immutable.
- Delete is not idempotent — returns 404 if the note does not exist.
- 404 returns RFC 9457 ProblemDetail with `title: "Note Not Found"`.

## Validation commands
```bash
# Fast: unit tests only (no Docker needed)
scripts/harness/mvn -q test -Dtest="NoteTest,CreateNoteUseCaseTest,FindNoteByIdUseCaseTest,ListNotesUseCaseTest,UpdateNoteUseCaseTest,DeleteNoteUseCaseTest,NoteExceptionHandlerTest"

# Slice tests (Docker required)
scripts/harness/mvn -q test -Dtest="NoteRepositoryAdapterTest,NoteControllerSliceTest"

# Module test (Docker required)
scripts/harness/mvn -q test -Dtest="NotepadModuleTest"

# Integration test (Docker required)
scripts/harness/mvn -q verify -Dit.test="NotepadIT"

# Full verification
scripts/harness/mvn -q verify
```

## Rules for changes in this module
- Every `package-info.java` must have `@org.jspecify.annotations.NullMarked`. New subpackages need their own `package-info.java`.
- New internal classes must follow existing patterns per `.claude/rules/modulith.md`
- No other module may directly access this module's owned tables
- Update this contract when adding endpoints, tables, or behavioral obligations
- Update the consumer surface section when adding, changing, or removing endpoints or response shapes
- Integration tests for REST endpoints must include OpenAPI contract validation using `OpenApiContractValidator.assertResponseMatchesSpec` — see `testing.md` § "OpenAPI contract validation"
