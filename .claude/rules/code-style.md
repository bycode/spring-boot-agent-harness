---
paths:
  - "src/**/*.java"
  - "pom.xml"
---

# Code style and conventions

Formatting is tool-driven: Spotless and `google-java-format` are the source of truth for whitespace, wrapping, and import layout. Do not hand-tune formatting against the formatter.

When principles conflict: YAGNI > KISS > readability > DRY.
Use SOLID as design heuristics, not as a precedence rule.

## Scope

- This file covers stable source-style and `pom.xml` conventions.
- Runtime, security, persistence, testing, transaction, and AI rules live in the dedicated rule files for those concerns.
- Do not put volatile version notes or one-off framework gotchas here. Record those in `docs/learnings/LEARNINGS.md`.

## Java source rules

- One top-level type per file.
- No wildcard imports.
- Keep overloads contiguous.
- Use braces for `if`, `else`, `for`, `while`, and `do`, even for single-line bodies.
- Prefer switch expressions and exhaustive switches when the domain is closed (for example enums and sealed hierarchies).
- Use uppercase `L` for `long` literals.
- Keep `@SuppressWarnings` and tool-specific suppressions as narrow as possible, and explain why they are needed.
- Use `var` when the type is obvious from the initializer or the variable name makes it clear. Avoid `var` when the reader would need to chase the right-hand side to understand the type.
- Use unnamed variables (`_`) for intentionally unused values in switch branches, catch blocks, and lambda parameters.
- Use text blocks (`"""`) for multi-line string literals such as SQL queries, JSON payloads, and test fixtures. Do not use text blocks for single-line strings.
- Favor clear, direct code over clever abstractions, reflection tricks, or meta-programming.
- Composition over inheritance.

## Modeling and framework boundaries

- Prefer records for immutable data carriers whose state is the API: value objects, commands, query results, and request/response DTOs.
- Record components that hold collections or other mutable types must be defensively copied in a compact constructor using `List.copyOf()`, `Set.copyOf()`, `Map.copyOf()`, or equivalent. A record is only immutable if every component is immutable.
- Use sealed interfaces or classes only when the set of variants is intentionally closed and exhaustive handling matters. Sealed types intentionally invert the Open-Closed Principle: adding a variant forces every switch to update, and the compiler enforces completeness.
- Constructor injection only. No field-level `@Autowired`.
- Do not field-inject `@Value`; prefer constructor arguments or dedicated configuration properties.
- `Optional` is for return types only. Never use `Optional` as a parameter, field, record component, or DTO property.
- Parse raw input into strong domain types at adapter boundaries rather than scattering validation across service methods.
- Encode constraints in the type system using domain primitives: small records with validation in the compact constructor (e.g., `record EmailAddress(String value) { EmailAddress { /* validate */ } }`).
- Domain records and use cases stay free of Spring and framework annotations.
- Transaction boundaries belong on Facade/Service classes; see `transactions.md`.
- No mapping frameworks. Write explicit mappings at boundaries.
- Work inside-out: domain model first, application logic second, adapters and wiring last.

## Error handling

- Use unchecked exceptions only. Do not introduce checked exceptions in application code — they fight lambdas, streams, and Spring's own unchecked model.
- Domain exceptions should extend `RuntimeException`. For modules with multiple failure modes, a sealed exception hierarchy gives compile-time exhaustive handling (e.g., `sealed class NotepadException extends RuntimeException permits NoteNotFoundException, NoteConflictException`).
- Exception messages must include the entity type and the identifying value (e.g., `"Note not found: id=" + id`), not just `"not found"`.
- Never catch and ignore. If a catch block has no meaningful action, let the exception propagate.
- Never use exceptions for control flow. A lookup returning empty is not an exception; return `Optional` instead.
- HTTP error mapping (RFC 9457, `ProblemDetail`) is covered in `rest.md`.

## Functional style

- Prefer method references (`Foo::bar`) over equivalent lambdas (`x -> x.bar()`) when the reference reads clearly.
- Keep stream pipelines short. If a pipeline exceeds three or four intermediate operations, extract a named method for readability.
- Use a `for` loop instead of a stream when the operation is simple, mutates local state, needs early exit, or gains nothing from the functional form.
- Avoid nesting `Optional.flatMap` or `Optional.map` chains deeper than two levels. Extract a method or restructure the logic instead.
- Prefer `Stream.toList()` over `Collectors.toList()`. The former returns an unmodifiable list, consistent with immutability defaults.

## Class cohesion

- A class should own one coherent responsibility.
- If a group of private methods shares no instance state and can be moved without passing `this`, extract it.
- Prefer one level of abstraction per method.
- Keep the high-level flow near the top of the class; place helpers below their callers unless overload grouping dictates otherwise.

## Naming

- Packages: lowercase, no underscores.
- Types: `UpperCamelCase`. Methods, fields, parameters, and locals: `lowerCamelCase`.
- Methods should read like verbs or verb phrases.
- Constants use `UPPER_SNAKE_CASE` only for deeply immutable `static final` values.
- Avoid abbreviations unless they are standard in this domain: `ID`, `URL`, `HTTP`, `JSON`, `JWT`, `UUID`, `SQL`, `API`.
- Avoid one-letter names except for loop indices (`i`, `j`, `k`) and conventional exception variables (`e`). Use descriptive parameter names in lambdas.

Repo-specific naming:

- Public module interfaces: `*API`
- DTO classes: `*DTO`
- Use cases: verb phrase + `UseCase`
- Domain types: no technical suffix
- Test classes: end with `Test`

## Lombok

- Lombok is limited to annotations that eliminate pure ceremony without hiding behavior: `@Slf4j`, `@With`, `@Builder`.
- Disallowed annotations: `@Data`, `@Getter`, `@Setter`, `@Value`, `@AllArgsConstructor`, `@NoArgsConstructor`, `@RequiredArgsConstructor`, and similar boilerplate-hiding shortcuts. Records and sealed types handle what those did.

## Logging

- Use Lombok `@Slf4j` when a class genuinely needs logging. Never use `LoggerFactory.getLogger()` manually.
- Prefer event-based logs over boilerplate method entry/exit logs.
- Good log points: state changes at module boundaries, external calls, retries and fallbacks, scheduled/background work, security-relevant events, and unexpected conditions.
- `DEBUG`: local diagnostic detail.
- `INFO`: important lifecycle or business-significant events.
- `WARN`: recoverable or degraded behavior.
- `ERROR`: failures that require attention. Include the exception as the last argument.
- Use SLF4J `{}` placeholders. Never concatenate log messages.
- For structured key-value data, prefer the fluent API: `log.atInfo().addKeyValue("noteId", id).log("Note created")`.
- Log-level guards are unnecessary for simple placeholder logs, but are allowed when argument construction is expensive or side-effectful.
- Use a stable prefix such as `[ClassName.methodName]` on manually written log messages.
- Prefer framework observability and tracing for cross-request flow visibility instead of manual entry/exit noise.
- Never log secrets, passwords, access tokens, connection strings, key material, raw authorization headers, or PII.
- Do not log from the domain layer, records/DTOs, or tight loops unless there is a compelling operational reason.

## Null safety

This project uses JSpecify annotations enforced by NullAway at compile time.

- Every `package-info.java` must have `@org.jspecify.annotations.NullMarked`.
- Non-null is the default inside `@NullMarked` scope.
- Use `@Nullable` only where `null` is genuinely part of the contract.
- Never use `@Nullable Optional<T>`.
- Never use older nullness annotation sets such as JSR-305, JetBrains, or FindBugs/SpotBugs annotations.
- Subpackages do not inherit `@NullMarked`. Every package with Java source files needs its own `package-info.java`.
- Use `@NullUnmarked` only as a temporary escape hatch. Keep its scope minimal and document why it is needed.

## pom.xml conventions

- Prefer Spring Boot starters and BOM-managed versions.
- Do not add a `<version>` for dependencies already managed by the Spring Boot parent/BOM unless there is a documented reason.
- Override managed versions only for an unmanaged dependency, a verified security or compatibility need, or a deliberate repo-wide BOM import.
- Keep `dependencyManagement` for BOM imports and true repo-wide version control, not routine per-dependency pinning.
- Keep test-only dependencies in `test` scope.
- Remove redundant or duplicate dependencies instead of layering around them.
