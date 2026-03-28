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

## Public API (root package)

| Type | Role |
|------|------|
| `NotepadAPI` | Module API interface |
| `Note` | Domain record |
| `Page` | Generic pagination container |
| `NoteNotFoundException` | Domain exception |

## Hidden packages (implementation details)

| Package | Contains |
|---------|----------|
| `internal/` | `NotepadFacade`, `CreateNoteUseCase`, `FindNoteByIdUseCase`, `ListNotesUseCase`, `UpdateNoteUseCase`, `DeleteNoteUseCase`, `NotePersistencePort`, `NotepadModuleConfiguration` |
| `persistence/` | `NoteEntity`, `NoteRepository`, `NoteRepositoryAdapter` |
| `rest/` | `NoteController`, `CreateNoteRequestDTO`, `UpdateNoteRequestDTO`, `NoteResponseDTO`, `NotePageResponseDTO`, `NoteExceptionHandler` |

## Allowed dependencies
None

## Cross-module communication
- **Direct API calls**: None — this module has no dependencies.
- **Events**: None published or consumed.

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
./mvnw -q test -Dtest="NoteTest,CreateNoteUseCaseTest,FindNoteByIdUseCaseTest,ListNotesUseCaseTest,UpdateNoteUseCaseTest,DeleteNoteUseCaseTest,NoteExceptionHandlerTest"

# Slice tests (Docker required)
./mvnw -q test -Dtest="NoteRepositoryAdapterTest,NoteControllerSliceTest"

# Module test (Docker required)
./mvnw -q test -Dtest="NotepadModuleTest"

# Integration test (Docker required)
./mvnw -q verify -Dit.test="NotepadIT"

# Full verification
./mvnw -q verify
```

## Rules for changes in this module
- Every `package-info.java` must have `@org.jspecify.annotations.NullMarked`. New subpackages need their own `package-info.java`.
- New public types in root package must be added to the "Public API" table above
- New internal classes must follow existing patterns per `.claude/rules/modulith.md`
- No other module may directly access this module's owned tables
- Update this contract when adding public API types, endpoints, tables, or dependencies
- Keep `package-info.java` in sync with the "Allowed dependencies" section above
- Update the consumer surface section when adding, changing, or removing endpoints or response shapes
