---
paths:
  - "src/main/java/nl/jinsoo/template/*/**"
  - "src/test/java/nl/jinsoo/template/*/**"
  - "src/main/java/nl/jinsoo/template/package-info.java"
  - "src/test/java/nl/jinsoo/template/ModularityVerificationTest.java"
  - ".claude/rules/modules/**"
---

# Spring Modulith modules

## Module structure

| Package | Visibility | Contains |
|---------|-----------|----------|
| `module/` (root) | **Public API** | Module API interface, domain records, domain exceptions, domain enums |
| `module/internal/` | Hidden | Use cases, port interfaces, `@Configuration` wiring |
| `module/persistence/` | Hidden | Spring Data JDBC adapters, entity records, Spring Data interfaces |
| `module/rest/` | Hidden | Controllers, request/response DTOs |

Spring Modulith hides all subpackages automatically. Only root package types are visible to other modules.

## Module complexity

- **flat**: All classes in root package. Only `public` types form the public API; implementation classes use package-private visibility. For simple modules (≤5 classes, no REST, trivial persistence).
- **standard**: `internal/`, `persistence/`, `rest/` subpackages. For modules with business logic, persistence adapters, and REST exposure.

## Module API

- One interface per module (e.g., `<Module>API`) in root package
- Standard modules: implementation lives in `internal/`, package-private
- Flat modules: implementation lives in root package with package-private visibility
- Wired as `@Bean` in the module's `@Configuration` class

## Cross-module rules

- Depend on other modules only through types published in their root package: synchronous coordination goes through `<Module>API`; events are imported from the publisher's root package
- Never import from another module's `internal/`, `persistence/`, or `rest/`
- `ApplicationModules.verify()` enforces at test time
- Declare allowed dependencies in `package-info.java` via `@ApplicationModule(allowedDependencies = ...)`

## Cross-module communication

- **Direct API calls** for any interaction that needs a result or synchronous coordination
- **Events** for state-changing notifications (fire-and-forget)
- Use `@ApplicationModuleListener` for event listeners
- Event records live in the **publishing module's root package**

## Domain records (root package)

- Zero Spring/framework annotations
- No `toResponse()`, `toEntity()`, `toDto()` methods
- Sealed exception hierarchies extending `RuntimeException`, with domain context (IDs, names), no HTTP codes

## Use cases

Placement: `internal/` for standard modules, root package for flat modules.

- One public `execute(...)` method per class
- Constructor-inject port interfaces (not implementations)
- No `@Service` — registered via `@Configuration` + `@Bean`
- No `@Transactional` on use cases — transaction boundaries belong on Facade/Service (see `transactions.md`)
- Port interfaces: plain Java, domain types only, `public` for cross-subpackage visibility

## Complete module anatomy

A finished module contains:

**Always required:**
- `package-info.java` with `@NullMarked` and `@ApplicationModule(allowedDependencies = ...)` (+ per-subpackage `package-info.java` for standard modules)
- Domain types in root package: `<Module>API` interface, domain records, domain exceptions
- Use cases and port interfaces (in `internal/` for standard, root for flat)
- Configuration: `@Configuration` class wiring use cases as `@Bean`s
- Tests: unit (fakes/mocks), module (`@ApplicationModuleTest`)
- Module contract at `.claude/rules/modules/<module>.md`

**When applicable:**
- Persistence: Flyway migration, entity record, repository, adapter with `@Component` — see `persistence.md`
- REST (standard only): `@RestController`, request/response DTOs — see `rest.md`
- Exception handling (modules with REST): module-local `@RestControllerAdvice` with RFC 9457 ProblemDetail — see `rest.md`
- Additional tests: persistence slice (`@DataJdbcTest`), REST slice (`@WebMvcTest`), integration (`@SpringBootTest`) — see `testing.md`

## Creating a new module

Use `scripts/harness/new-module <module-name> <flat|standard> [allowed-dependencies]` to scaffold. The script generates the directory structure, `package-info.java` files, initial API interface, domain record, module contract, and module-local `AGENTS.md`.

After scaffolding, fill in the TODOs in the generated module contract and implement the module following the anatomy above. Run `./mvnw -q verify` as a post-scaffold sanity check. Use `scripts/harness/full-check` as the completion gate before considering the module done.

## Module contracts

- Each module MUST have a contract at `.claude/rules/modules/<module-name>.md`
- Contracts must be path-scoped to the full module slice (both main and test sources):
  ```yaml
  paths:
    - "src/main/java/nl/jinsoo/template/<module>/**"
    - "src/test/java/nl/jinsoo/template/<module>/**"
  ```
- See `MODULE-TEMPLATE.md` for required structure
- Module boundaries must enable safe parallel work — no shared mutable state across module boundaries

## Anti-patterns

- Don't use events for request/response — call the API directly when you need a result
- Events belong to the publisher, not a shared package
- Never use `@ApplicationModule(type = Type.OPEN)` in new modules
- Don't check-then-act in use cases (`existsById` followed by `deleteById`). Design port methods to return operation results and branch on the return value. See `persistence.md` § "Concurrency"
