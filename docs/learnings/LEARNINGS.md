# Learnings

Known gotchas and non-obvious behaviours discovered during development. Scan this file before starting work on related areas.

---

## Durable version gotchas

These are permanently relevant for the current stack (Java 25, Spring Boot 4, Spring Framework 7).

### Spring Boot 4.x / Spring Framework 7 (2026-03-15)

- `RestTestClient` lives in `org.springframework.test.web.servlet.client` (Spring Framework 7), not `org.springframework.boot.test.web.client` or `org.springframework.test.web.client`.
- `AutoConfigureRestTestClient` moved to `org.springframework.boot.resttestclient.autoconfigure`.
- `RestTestClient.RequestBodySpec` uses `.body(Object)`, not `.bodyValue()`.
- `RestTestClient` jsonPath assertions use `Consumer<T>` lambdas, not Hamcrest matchers.
- `@MockitoBean` replaces `@MockBean`. `MockMvcTester` replaces raw `MockMvc`. `TestRestTemplate` is gone.

### Spring Data JDBC 4.x (2026-03-15)

- Explicit `@Id` required on entity ID fields — no longer auto-detected by convention.
- JDBC auto-config package moved: `org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration`. Spring Data JDBC auto-config at `org.springframework.boot.data.jdbc.autoconfigure.DataJdbcRepositoriesAutoConfiguration`.
- Entities with non-null `@Id` trigger UPDATE, not INSERT. For pre-assigned IDs, add `@Version Integer version`.
- SpotBugs flags mutable `Set` fields in records as `EI_EXPOSE_REP`/`EI_EXPOSE_REP2`. Spring Data JDBC requires mutable collections for `@MappedCollection`. Suppress in `spotbugs-exclude.xml`.

### Jackson 3 (2026-03-15)

- Maven group: `tools.jackson` (not `com.fasterxml.jackson`).
- `JacksonException` is now `RuntimeException`, not `IOException`.
- Renamed: `@JsonComponent` → `@JacksonComponent`, `JsonDeserializer` → `ValueDeserializer`, `JsonSerializer` → `ValueSerializer`.

### Spring Boot 4.x HTTP Clients (2026-03-15)

- `AutoConfigureTestDatabase` moved to `org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase`.
- `RANDOM_PORT` + `localhost:${server.port}` fails (resolves to 0). Use `DEFINED_PORT` for self-referencing HTTP.

### NullAway + Error Prone (2026-03-22)

- `AnnotatedPackages` and `OnlyNullMarked` flags are mutually exclusive. NullAway throws `IllegalStateException` if both are set.
- Forked compilation (`<fork>true</fork>`) swallows all Error Prone/NullAway error messages — Maven captures no compiler output from the forked javac process. Use in-process compilation with `--add-exports`/`--add-opens` in `.mvn/jvm.config` instead.
- Java package annotations (`@NullMarked` on `package-info.java`) do NOT propagate to subpackages. Each subpackage needs its own `package-info.java` with `@NullMarked`, otherwise `OnlyNullMarked` mode silently skips it.
- Error Prone 2.48.0 and NullAway 0.13.1 work with Java 25 without issues.

### Tooling compatibility (2026-03-15)

- **Spotless**: Requires 3.0.0+ and Google Java Format 1.27.0+ for Java 25.
- **ArchUnit**: Requires 1.4.1+ for Java 25 class file format. Use `.allowEmptyShould(true)` for zero-match rules.
- **JaCoCo**: Requires 0.8.14+ for Java 25. Minor coverage issue with `switch` + `String` + `forEach`.
- **JaCoCo Maven Plugin**: `prepare-agent` appends to an existing `target/jacoco.exec` by default. Set `append=false` to keep repeated `verify` runs deterministic after interrupted builds.
- **springdoc-openapi**: v3.x for Spring Boot 4 (v2.x for Boot 3). v3.0.2 aligns with Boot 4.0.3.
- **Flyway 11+**: Requires separate `flyway-database-postgresql` module.
- **Testcontainers**: Requires 1.21.4+ for Docker Engine 29 (API version 1.44).

### JaCoCo `append=false` corrupts exec file on Java 25 (2026-03-16)

- Setting `<append>false</append>` on JaCoCo's `prepare-agent` produces an all-zeros `jacoco.exec` when Surefire forks a JVM on Java 25. The JaCoCo `check` goal then fails with "Invalid execution data file."
- Root cause: the agent pre-allocates the file but with `append=false` the data is never properly flushed in the forked process.
- Fix: remove `<append>false</append>` from the `prepare-agent` configuration. The default (`append=true`) works correctly.
- The `@{argLine}` must also be explicitly set in the Surefire plugin configuration to ensure the JaCoCo agent is passed to the forked JVM.

### Mockito dynamic agent loading on Java 25 (2026-03-16)

- Mockito self-attaches ByteBuddy as a Java agent at runtime, which triggers warnings on Java 25 and will be disallowed by default in a future JDK.
- Fix: add `-XX:+EnableDynamicAgentLoading` to the Surefire `<argLine>` to suppress warnings.
- Long-term: configure Mockito as a static agent via `<javaagentModule>` when the Mockito team ships static agent support.

### Method validation: do NOT use @Validated on controllers (2026-03-28)

- In Spring MVC 6.1+ / Spring Boot 4, constraint annotations (`@Min`, `@Max`, `@Size`, etc.) on `@RequestParam` / `@PathVariable` parameters are validated natively by the MVC framework **without** `@Validated` on the controller class. Violations throw `HandlerMethodValidationException`, which the ProblemDetail handler converts to 400.
- Adding `@Validated` to the controller class activates AOP-based validation via `MethodValidationPostProcessor` instead, which throws `ConstraintViolationException`. That exception is **not** auto-handled as 400 — it falls through to the catch-all handler and returns 500.
- Rule: never put `@Validated` on `@RestController` classes. Just annotate method parameters with Jakarta Validation constraints and let the MVC framework handle them.

### @Transactional and non-bean use cases (2026-03-16)

- `@Transactional` on UseCase classes has no effect because use cases are plain Java objects created via `new` in `@Configuration` classes. Only Spring-managed beans (Facade/Service returned from `@Bean`) support AOP-based `@Transactional`. Place `@Transactional` on Facade/Service methods.

### Spring Modulith (2026-03-15)

- `@ApplicationModuleTest` defaults to `BootstrapMode.STANDALONE`. Use `DIRECT_DEPENDENCIES` for cross-module tests.
- Subpackages auto-hidden. Only root package types are public API.
- Spring Boot 4 parent POM does not manage Modulith versions — explicit BOM needed.

### Testcontainers + PostgreSQL (2026-03-15)

- `@DataJdbcTest` replaces datasource with embedded DB unless `@AutoConfigureTestDatabase(replace = NONE)`.
- `@ServiceConnection` auto-configures datasource — no `@DynamicPropertySource` needed.
- PostgreSQL is case-sensitive for quoted identifiers. Use lowercase in DDL.

---

## Historical debugging notes

These are one-off issues encountered during initial setup. May not recur but kept for reference.

### PMD GuardLogStatement (2026-03-15)

PMD flags `log.info("...", someList.size())` — extract to local variable first.

### E2E testing profile (2026-03-15)

The `e2etest` profile disables CSRF and auth entirely. Browser testing under this profile won't catch missing CSRF tokens. Always code-review CSRF handling separately.

### Module-local @RestControllerAdvice ordering (2026-03-17)

Module-scoped `@RestControllerAdvice(assignableTypes = Controller.class)` needs `@Order(Ordered.HIGHEST_PRECEDENCE)` to take precedence over `GlobalExceptionHandler`. Without explicit ordering, the global catch-all `@ExceptionHandler(Exception.class)` may execute first.

### @WebMvcTest CSRF and SecurityConfig (2026-03-17)

`@WebMvcTest` does not auto-load user `SecurityConfig`. Default Spring Security applies (CSRF enabled), so POST tests return 403. Fix: `@Import(SecurityConfig.class)` with `@TestPropertySource(properties = "jwt.secret-key=...")` to load the real security chain (which disables CSRF).

### @WithMockUser does not work with RestTestClient at RANDOM_PORT (2026-03-17)

`@WithMockUser` only populates the SecurityContext in-process (MockMvc/MockMvcTester). For real HTTP via `RestTestClient`, generate a JWT programmatically using the dev HMAC signing key and pass it as a Bearer token header.

### JaCoCo exec file corruption between runs (2026-03-17)

If `mvnw verify` fails with `Unknown block type` in JaCoCo, delete `target/jacoco.exec` and retry. The corruption occurs when a previous test run was interrupted.
