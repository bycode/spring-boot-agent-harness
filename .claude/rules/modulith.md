---
paths:
  - "src/**/internal/**"
  - "src/main/java/nl/jinsoo/template/**/*.java"
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

- **flat**: All classes in root package, package-private visibility. For simple modules (≤5 classes, no REST, trivial persistence).
- **standard**: `internal/`, `persistence/`, `rest/` subpackages. For modules with business logic, persistence adapters, and REST exposure.

## Module API

- One interface per module (e.g., `<Module>API`) in root package
- Implementation lives in `internal/`, package-private
- Wired as `@Bean` in the module's `@Configuration` class

## Cross-module rules

- Depend on other modules ONLY via their public API interface
- Never import from another module's `internal/`, `persistence/`, or `rest/`
- `ApplicationModules.verify()` enforces at test time
- Declare allowed dependencies in `package-info.java` via `@ApplicationModule(allowedDependencies = ...)`

## Cross-module communication

- **Direct API calls** for reads/queries (synchronous)
- **Events** for state-changing notifications (fire-and-forget)
- Use `@ApplicationModuleListener` for event listeners
- Event records live in the **publishing module's root package**

## Domain records (root package)

- Zero Spring/framework annotations
- No `toResponse()`, `toEntity()`, `toDto()` methods
- Sealed exception hierarchies extending `RuntimeException`, with domain context (IDs, names), no HTTP codes

## Use cases (`internal/` package)

- One public `execute(...)` method per class
- Constructor-inject port interfaces (not implementations)
- No `@Service` — registered via `@Configuration` + `@Bean`
- No `@Transactional` on use cases — transaction boundaries belong on Facade/Service (see `transactions.md`)
- Port interfaces: plain Java, domain types only, `public` for cross-subpackage visibility

## Creating a new module

1. **Create `package-info.java`** with `@NullMarked` and `@ApplicationModule(allowedDependencies = ...)`. For standard modules, also create `package-info.java` with `@NullMarked` in each subpackage (`internal/`, `persistence/`, `rest/`)
2. **Domain first** (root package): `<Module>API` interface, domain records, domain exceptions
3. **Use cases** (internal/ for standard, root for flat)
4. **Port interfaces** (internal/ for standard)
5. **Persistence**: Flyway migration, entity record with `@Id`/`@Table`/`toDomain()`/`from()`, repository extending `ListCrudRepository`, adapter with `@Component`
6. **REST** (standard only): `@RestController`, request DTO with `toDomain()`, response DTO with `from()`
7. **Configuration**: `@Configuration` class wiring use cases as `@Bean`s
8. **Exception handling**: Module-local `@RestControllerAdvice(assignableTypes = <Controller>.class)` with RFC 9457 ProblemDetail. Reserve `GlobalExceptionHandler` for cross-cutting concerns only (e.g., the catch-all 500 handler).
9. **Tests**: Unit (fakes/mocks), persistence slice (`@DataJdbcTest`), REST slice (`@WebMvcTest`), module (`@ApplicationModuleTest`), integration (`@SpringBootTest`)
10. **Module contract**: Copy `MODULE-TEMPLATE.md` to `.claude/rules/modules/<module>.md`
11. **Verify**: `./mvnw -q verify`

## Module contracts

- Each module MUST have a contract at `.claude/rules/modules/<module-name>.md`
- See `MODULE-TEMPLATE.md` for required structure
- Module boundaries must enable safe parallel work — no shared mutable state across module boundaries

## Anti-patterns

- Don't use events for request/response — call the API directly for queries
- Events belong to the publisher, not a shared package
- Never use `@ApplicationModule(type = Type.OPEN)` in new modules
- Don't check-then-act in use cases (`existsById` followed by `deleteById`). Design port methods to return operation results and branch on the return value. See `persistence.md` § "Concurrency"
