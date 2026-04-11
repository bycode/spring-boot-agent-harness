---
paths:
  - "src/test/**"
---

# Testing rules

## Regression-first rule

For **bug fixes**, **public API behavior changes**, and **risky refactors**: write one failing
regression or acceptance test at the smallest useful layer *before* changing production code.

- **Bug fix**: the test reproduces the bug. It fails before the fix, passes after.
- **API behavior change**: the test asserts the new expected behavior. It fails against the current code.
- **Risky refactor**: a characterization test pins existing behavior. It passes before and after.

"Smallest useful layer" means: unit test if the behavior is pure logic, slice test if it needs
a database or HTTP layer, integration test only if the bug spans layers.

This does not apply to: new features (greenfield code has nothing to regress against),
configuration changes, documentation, or trivial changes where the existing test suite
already covers the behavior.

## Summary

- Target platform only: Java 25, Spring Boot 4.x, Spring Framework 7.x, Spring AI 2.x, JUnit 6.x, Testcontainers 2.x. Do not preserve Spring Boot 3.x, Spring AI 1.x, JUnit 5.x, or Testcontainers 1.x compatibility in test code, examples, or guidance.
- Prefer the smallest test that proves behavior: unit -> slice -> module -> integration.
- Bias heavily toward unit and slice tests. Keep full integration tests minimal and high-signal.
- No live network calls in automated tests. Databases use Testcontainers. External HTTP systems and hosted AI providers are stubbed or replaced with local/containerized services.
- Spring AI testing is part of the repo standard, not an optional add-on. For AI-specific dependency, provider, and pgvector rules, also read [`spring-ai.md`](spring-ai.md).

## Project-standard Spring Boot 4 / Framework 7 test APIs

These are repo standards for new code. They are not all framework deprecations.

| Concern | Project standard | Avoid in new code |
|-----|------------------|-------------------|
| Bean overrides | `@MockitoBean`, `@MockitoSpyBean`, `@TestBean` | `@MockBean`, `@SpyBean` (deprecated for removal in Boot 4) |
| MVC controller assertions | `MockMvcTester` | raw `MockMvc` unless `MockMvcTester` cannot express the needed assertion |
| Full HTTP integration | `RestTestClient` | `TestRestTemplate` |
| Outbound HTTP client slice | `@RestClientTest` | `@SpringBootTest` for simple client serialization/error-mapping tests |

Nudge: scripts/harness/lib/hook-checks.sh::check_deprecated_test_api — PostToolUse hook flags `@MockBean`, `@SpyBean`, `TestRestTemplate`, `SpringRunner`, `SpringClassRule`, `SpringMethodRule`, and the legacy Testcontainers PostgreSQLContainer import in any `src/test/java/**/*.java` file and names the project-standard replacement from the table above.

### Import paths (Spring Boot 4.0.3+ / Spring Framework 7.x)

```java
import org.springframework.boot.data.jdbc.test.autoconfigure.DataJdbcTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.restclient.test.autoconfigure.RestClientTest;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.convention.TestBean;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.client.RestTestClient;
```

### Testcontainers 2.x import paths

Testcontainers 2.0 relocated all container classes to module-specific packages. Use these imports — the old `org.testcontainers.containers.*` paths are deprecated.

```java
import org.testcontainers.postgresql.PostgreSQLContainer;  // was org.testcontainers.containers.PostgreSQLContainer
```

Note: `PostgreSQLContainer` is no longer generic in TC 2.0 — use `PostgreSQLContainer` not `PostgreSQLContainer<?>`.

### JUnit 6 baseline

Spring Boot 4 ships with JUnit 6 (Jupiter). JUnit 4 support (`SpringRunner`, `SpringClassRule`, `SpringMethodRule`) is deprecated in Spring Framework 7. Do not use Vintage compatibility.

Notable JUnit 6 features available in this project:
- **`@ParameterizedClass`** (experimental): class-level parameterization — instantiate test classes with different constructor arguments.
- **`@ClassTemplate`** (experimental): extensible class-level test templates.
- **Deterministic `@Nested` ordering**: `ClassOrderer.Default` provides consistent ordering across runs.
- **Unified versioning**: Platform, Jupiter, and Vintage share one version number.
- **JSpecify annotations**: JUnit 6 modules are annotated with `@NullMarked`, matching this project's null-safety strategy.

## Assertion libraries

AssertJ is the primary assertion API. Do not mix JUnit `assertEquals` / `assertTrue` with AssertJ `assertThat` in the same test class.

For exception assertions, match the style of the rest of the class:

| Class assertion style | Exception assertion | Example |
|-----------------------|--------------------|---------|
| AssertJ (preferred) | `assertThatExceptionOfType` / `assertThatThrownBy` | `assertThatExceptionOfType(NoteNotFoundException.class).isThrownBy(() -> ...).withMessageContaining("id=42")` |
| JUnit | `assertThrowsExactly` | `assertThrowsExactly(NoteNotFoundException.class, () -> ...)` |

## Bean override gotchas

- Use `@MockitoBean(enforceOverride = true)` or `@TestBean(enforceOverride = true)` when overriding a bean that **exists in the test's application context** (e.g., `@SpringBootTest`, `@ApplicationModuleTest`). Without `enforceOverride`, `@MockitoBean` defaults to `REPLACE_OR_CREATE` — it silently creates a mock even if no matching bean exists, masking wiring errors.
- Do **not** use `enforceOverride = true` in `@WebMvcTest` slices for module API dependencies — these beans are not loaded in the web slice context. The mock is creating the bean, not replacing one. Using `enforceOverride = true` here causes context loading failure.
- When using `@MockitoSpyBean`, always stub with `doReturn(...).when(spy).method()` instead of `when(spy.method()).thenReturn(...)`. The latter calls the real method during stub setup, causing side effects (exceptions, state changes, database writes).
- `@MockitoBean` and `@TestBean` can only be placed on **non-static fields in test classes** — not on `@Configuration` classes. This is a difference from the old `@MockBean`.

## Tier 1: Unit tests (domain + application)

- **Domain**: test business rules, invariants, state transitions, value semantics, and exception contracts. Do not mock domain objects.
- **Application (use cases)**: prefer in-memory fakes for port interfaces when the use case has real logic (branching, validation, multi-step flows, consistency across calls). Mockito is acceptable for simple delegation use cases where a fake adds no value.

```java
// In-memory fake — use for use cases with business logic
class InMemoryOrderPersistence implements OrderPersistencePort {
    private final Map<Long, Order> store = new HashMap<>();
    // implement save, findById, etc. — behaves like a real store
}

// Mockito mock — acceptable for simple pass-through use cases
var port = mock(OrderPersistencePort.class);
when(port.save(any())).thenReturn(expectedOrder);
```

### When to use fakes vs mocks

| Use case complexity | Recommended | Why |
|---|---|---|
| Has branching, validation, or multi-step logic | In-memory fake | Fake catches logic bugs that mocks miss |
| Simple delegation (one-liner) | Either — Mockito is fine | Both test the same thing; mock is less code |
| Calls multiple port methods that must be consistent | In-memory fake | Fake ensures save -> find returns the saved value |

## Tier 2: Slice tests (one adapter layer)

### Persistence: `@DataJdbcTest` + Testcontainers

```java
@DataJdbcTest
@Import({OrderRepositoryAdapter.class, TestcontainersConfiguration.class})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
```

- Uses real PostgreSQL via Testcontainers — test against the same database engine as production.
- `@AutoConfigureTestDatabase(replace = NONE)` prevents Spring from replacing the datasource with an embedded DB.
- Flyway migrations run automatically against the container, so schema is always up to date.
- Test round-trip persistence, custom queries, optimistic locking, and database edge cases.

### REST controller: `@WebMvcTest`

```java
@WebMvcTest(OrderController.class)
class OrderControllerSliceTest {
    @Autowired MockMvcTester mvc;

    @MockitoBean(enforceOverride = true)
    CreateOrderUseCase createOrderUseCase;
}
```

- Use `MockMvcTester` for request/response assertions (see example below).
- Test HTTP status codes, response body, request validation, serialization, error responses (RFC 9457), and security behavior.
- Do not test business logic here. No database container needed unless the slice deliberately imports persistence.

#### `MockMvcTester` assertion patterns

```java
// GET — status + JSON body
assertThat(mvc.get().uri("/api/orders/{id}", 1))
    .hasStatusOk()
    .hasContentTypeCompatibleWith(MediaType.APPLICATION_JSON)
    .bodyJson().extractingPath("$.id").isEqualTo(1);

// POST — status + location header
assertThat(mvc.post().uri("/api/orders")
        .contentType(MediaType.APPLICATION_JSON)
        .content(requestBody))
    .hasStatus(HttpStatus.CREATED)
    .headers().hasValue("Location", "/api/orders/1");

// Validation error — RFC 9457 problem detail
assertThat(mvc.post().uri("/api/orders")
        .contentType(MediaType.APPLICATION_JSON)
        .content(invalidBody))
    .hasStatus(HttpStatus.BAD_REQUEST)
    .bodyJson().extractingPath("$.type").asString().isEqualTo("about:blank");
```

### `@TestBean` usage

`@TestBean` replaces a bean with a value from a static factory method — no Mockito needed. Use it when a deterministic fake is a better fit than a mock.

```java
@WebMvcTest(OrderController.class)
class OrderControllerSliceTest {
    @TestBean(enforceOverride = true)
    CreateOrderUseCase createOrderUseCase;

    // Factory method: must be static, no-arg, name matches the field name
    static CreateOrderUseCase createOrderUseCase() {
        return new FakeCreateOrderUseCase();
    }
}
```

Rules:
- The factory method **must be `static`** and accept **no arguments**.
- Default name: same as the annotated field (field `createOrderUseCase` -> method `createOrderUseCase()`).
- Override with `methodName`: `@TestBean(methodName = "org.example.TestUtils#createService")` for external classes.
- Factory methods are searched in: the test class, superclasses, implemented interfaces, and (for `@Nested` tests) the enclosing class hierarchy.

### Validation and security in controller slices

- If the test should exercise the real application security chain, explicitly import the real `SecurityConfig`.
- Use Spring Security test support (`@WithMockUser`, request post-processors, CSRF helpers) only for in-process MVC tests (`MockMvc` / `MockMvcTester`).
- Do not use `@WithMockUser` for real HTTP tests with `RestTestClient` — it bypasses the real auth chain, masking integration bugs. For `RANDOM_PORT` tests, send real JWT bearer tokens.

### Outbound HTTP adapter: `@RestClientTest`

```java
@RestClientTest(RemoteCatalogClient.class)
class RemoteCatalogClientTest {
    @Autowired private MockRestServiceServer server;
}
```

- Use for adapters built on `RestClient.Builder` or `RestTemplateBuilder`.
- Prefer it over `@SpringBootTest` when testing request construction, headers, serialization, retries, and remote error mapping.

## Tier 2.5: Module tests (`@ApplicationModuleTest`)

```java
@ApplicationModuleTest
@Import(TestcontainersConfiguration.class)
class PaymentModuleTest {
    @Autowired private PaymentAPI paymentAPI;
}
```

- Tests module wiring through the public API interface, not REST endpoints.
- Defaults to `BootstrapMode.STANDALONE`: only the module under test is loaded. Use `@ApplicationModuleTest(BootstrapMode.DIRECT_DEPENDENCIES)` when the module depends on other modules.
- Import `TestcontainersConfiguration` when the module touches the database.
- Every module must have at least one `@ApplicationModuleTest` (ADR-001).
- Cover create/find/update flows through the module API, exception paths, and wiring correctness.

## Test data isolation

Tests must not depend on execution order or state left by other tests.

| Test tier | Isolation strategy |
|-----------|-------------------|
| Unit tests | No shared state — each test constructs its own objects |
| `@DataJdbcTest` slice tests | `@Transactional` rollback (applied by default by Spring) |
| `@ApplicationModuleTest` | `@Transactional` rollback when testing through API without HTTP; explicit cleanup with HTTP |
| `@SpringBootTest(RANDOM_PORT)` | Explicit cleanup: `TRUNCATE` in `@BeforeEach`. `@Transactional` does **not** work — HTTP executes in a separate thread/transaction |

Use `@BeforeEach` cleanup (not `@AfterEach`) — if a previous run was interrupted, `@AfterEach` never ran and the next run starts with stale data.

```java
// Integration test cleanup pattern
@BeforeEach
void cleanDatabase(@Autowired JdbcTemplate jdbc) {
    jdbc.execute("TRUNCATE TABLE notes RESTART IDENTITY CASCADE");
}
```

## Tier 3: Integration tests

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Import(TestcontainersConfiguration.class)
```

- `@SpringBootTest` in Spring Boot 4 no longer auto-configures MockMvc, TestRestTemplate, or WebTestClient. You must explicitly add `@AutoConfigureRestTestClient`. This is mandatory, not a convenience.
- Use real HTTP with `RestTestClient` against PostgreSQL via Testcontainers.
- Cover one happy path per endpoint group, key error paths, security boundaries, and cross-cutting concerns.
- Keep the set intentionally small. Do not duplicate what slice tests already prove.
- For authenticated endpoints, send real JWT bearer tokens — not `@WithMockUser`.

### `RestTestClient` assertion patterns

```java
@Autowired RestTestClient client;

// Fluent expectation API
client.get().uri("/api/orders/{id}", 1)
    .accept(MediaType.APPLICATION_JSON)
    .exchange()
    .expectStatus().isOk()
    .expectHeader().contentType(MediaType.APPLICATION_JSON)
    .expectBody().jsonPath("$.id").isEqualTo(1);

// AssertJ integration via RestTestClientResponse
var response = RestTestClientResponse.from(
    client.post().uri("/api/orders")
        .contentType(MediaType.APPLICATION_JSON)
        .body(requestBody)
        .exchange()
);
assertThat(response).hasStatus(HttpStatus.CREATED);
```

### OpenAPI contract validation

Integration tests must validate response shapes against the committed `docs/generated/openapi.json`. This catches structural drift (wrong fields, missing properties, type mismatches) that hand-written jsonPath assertions miss.

Use `OpenApiContractValidator.assertResponseMatchesSpec(method, path, status, body, contentType)` after the existing assertion chain. Add `.returnResult()` at the end of the expectation chain to capture the response.

```java
// Responses with body — append .returnResult(), then validate
var result = client.get().uri("/api/orders/{id}", 1)
    .exchange()
    .expectStatus().isOk()
    .expectBody()
    .jsonPath("$.id").isEqualTo(1)
    .returnResult();

OpenApiContractValidator.assertResponseMatchesSpec(
    "GET", "/api/orders/1", 200, result.getResponseBody(), "application/json");

// Empty responses (204, 202) — no body to capture
client.delete().uri("/api/orders/{id}", 1)
    .exchange()
    .expectStatus().isNoContent();

OpenApiContractValidator.assertResponseMatchesSpec(
    "DELETE", "/api/orders/1", 204, null, null);

// Error responses — use application/problem+json for RFC 9457
var errorResult = client.get().uri("/api/orders/999")
    .exchange()
    .expectStatus().isNotFound()
    .expectBody()
    .returnResult();

OpenApiContractValidator.assertResponseMatchesSpec(
    "GET", "/api/orders/999", 404, errorResult.getResponseBody(), "application/problem+json");

// Query parameters — include in the path string
OpenApiContractValidator.assertResponseMatchesSpec(
    "GET", "/api/orders?page=0&size=10", 200, result.getResponseBody(), "application/json");
```

Rules:
- Every module with REST endpoints must have contract validation in its integration test.
- Validate at least: one success path per endpoint, one error path per distinct error status.
- Pass the actual path (e.g., `/api/notes/1`), not the template (`/api/notes/{id}`) — the validator resolves path parameters automatically.
- Use `"application/json"` for success responses and `"application/problem+json"` for RFC 9457 error responses.
- This complements `scripts/harness/check-openapi-drift` — drift detection checks the spec matches the app, contract validation checks individual responses match the spec.

Nudge: scripts/harness/lib/hook-checks.sh::check_contract_validator_in_it — PostToolUse hook flags any `*IT.java` file that imports `RestTestClient` or `MockMvcTester` without also importing `OpenApiContractValidator`.

## Spring AI 2.x testing

This repo is Spring AI 2.x only. Do not add Spring AI 1.x-compatible testing patterns.

- Read [`spring-ai.md`](spring-ai.md) alongside this file whenever a module depends on `ChatClient`, `ChatModel`, `EmbeddingModel`, vector stores, advisors, tools, or evaluators.
- **Unit / slice / module tests**: no live model or provider calls. Replace Spring AI collaborators with `@MockitoBean(enforceOverride = true)` or `@TestBean(enforceOverride = true)`.
- **Integration tests**: provider HTTP must be stubbed or backed by a local/containerized service. Never call OpenAI or another hosted provider from automated tests.
- **Tool calling**: test tool callbacks as plain Java first. Verify authorization, input validation, idempotency, and side effects independently of model behavior.
- **RAG / advisor flows**: when retrieval quality matters, add evaluation tests using Spring AI evaluators such as `RelevancyEvaluator` or `FactCheckingEvaluator` against deterministic fixtures.
- **Observability**: keep prompt/completion content logging disabled or sanitized by default in tests unless the test explicitly asserts on that content.
- **Vector stores**: use pgvector-enabled PostgreSQL containers when testing pgvector-backed flows.
- **Testcontainers**: when Spring AI provides a service connection for the local AI service or vector store, prefer the Spring AI Testcontainers integration over ad hoc wiring.

## Testcontainers best practices

- **Shared configuration**: Use a single `TestcontainersConfiguration` class with `@TestConfiguration(proxyBeanMethods = false)` and `@Bean @ServiceConnection PostgreSQLContainer`. In Testcontainers 2.0, `PostgreSQLContainer` is no longer generic — do not use `PostgreSQLContainer<?>`.
- **Explicit dependency**: Each test class that needs a database uses `@Import(TestcontainersConfiguration.class)` so the dependency is visible in the test.
- **Container lifecycle**: Containers declared as `@Bean @ServiceConnection` are tied to the Spring application context. Spring's TestContext Framework caches contexts, so test classes sharing the same configuration share the same container — no explicit singleton pattern needed.
- **Maximize context caching**: Avoid per-class `@SpringBootTest(properties = ...)` overrides — different properties create different contexts (and different containers). Use the shared `TestcontainersConfiguration` consistently.
- **Prefer bean-managed containers**: Declare containers as Spring beans in `@TestConfiguration`, not as static `@Container` fields. Bean-managed containers have guaranteed correct startup/shutdown ordering. JUnit-managed `@Container` fields may shut down before Spring beans are cleaned up, causing connection exceptions.
- **No `@DynamicPropertySource`**: Use `@ServiceConnection` instead. Only fall back to `@DynamicPropertySource` when service connections cannot express the dependency.
- **Docker required**: Docker must be running for slice/module/integration tests that need containers. Tier 1 unit tests remain container-free.
- **Context pausing (Spring Framework 7)**: cached application contexts are automatically paused when idle (Lifecycle/SmartLifecycle beans stopped). If tests fail due to Lifecycle components in stopped state, disable with `-Dspring.test.context.cache.pause=never`.
- **Local dev reuse (optional)**: Developers may enable `testcontainers.reuse.enable=true` in `~/.testcontainers.properties` and add `.withReuse(true)` to keep PostgreSQL running between test runs. If Flyway validation fails due to stale schema, remove the reused container and let Testcontainers create a fresh one.

## Async and event testing

Spring Modulith uses application events for cross-module communication. Awaitility ships with `spring-boot-starter-test` for async assertions.

- **Unit tests**: publish events manually via `ApplicationEventPublisher` (or a mock) and verify the handler logic directly.
- **Module/integration tests**: use Spring Modulith's `Scenario` API (`spring-modulith-test`) to verify event publication and consumption within a test transaction.

```java
// Scenario API — verify event flow through a module
@ApplicationModuleTest
@Import(TestcontainersConfiguration.class)
class OrderModuleTest {
    @Test
    void completingOrderPublishesEvent(Scenario scenario) {
        scenario.stimulate(() -> orderAPI.complete(orderId))
                .andWaitForEventOfType(OrderCompletedEvent.class)
                .toArriveAndVerify(event -> assertThat(event.orderId()).isEqualTo(orderId));
    }
}
```

- **Awaitility**: use for async operations outside the Modulith event model (scheduled tasks, background jobs). Prefer `await().atMost(...)` with explicit timeouts over arbitrary `Thread.sleep`.

## Test class naming conventions

Naming determines which Maven phase runs the test. Get this wrong and unit tests require Docker or integration tests are skipped.

| Test tier | Suffix | Example | Maven phase |
|-----------|--------|---------|-------------|
| Unit test | `*Test` | `OrderServiceTest` | `mvn test` (Surefire) |
| Slice test | `*Test` | `OrderControllerSliceTest` | `mvn test` (Surefire) |
| Module test | `*Test` | `OrderModuleTest` | `mvn test` (Surefire) |
| Integration test | `*IT` | `OrderEndpointIT` | `mvn verify` (Failsafe) |

- Surefire matches `*Test`, `*Tests`, `Test*` — all tiers except integration run here.
- Failsafe matches `*IT`, `*ITCase` — only full `@SpringBootTest(RANDOM_PORT)` integration tests.
- Never name a unit test `*IT` (it won't run during `mvn test`) or an integration test `*Test` (it will run during `mvn test` and fail without Docker).

Nudge: scripts/harness/lib/hook-checks.sh::check_test_naming — PostToolUse hook flags `@SpringBootTest(RANDOM_PORT)` in a non-`*IT` file and `@DataJdbcTest`/`@WebMvcTest`/`@RestClientTest`/`@ApplicationModuleTest` in an `*IT` file, naming the correct rename in each warning.

## Test organization

- Use `@Nested` classes to group related test cases by scenario (e.g., `@Nested class WhenNoteExists`). Pair with `@DisplayName` so test reports read as sentences.
- Limit nesting to two levels. Deeper nesting is a smell that the class under test has too many responsibilities.

## Test fixtures

Prefer deterministic fixture factories or builders in `src/test/java`, colocated with the package under test. One fixture helper per aggregate root or external adapter boundary is a good default.

## New production class → required tests

- New domain model: unit tests (creation, state transitions, validation, exception contracts)
- New use case: unit tests (fakes for complex logic, mocks acceptable for simple delegation)
- New repository adapter: `@DataJdbcTest` slice test with Testcontainers
- New controller: `@WebMvcTest` slice test
- New outbound HTTP client: `@RestClientTest`
- New module API or facade flow: `@ApplicationModuleTest`
- New endpoint group: `@SpringBootTest(RANDOM_PORT)` integration test with Testcontainers
- New Spring AI service, advisor, tool, or RAG flow: unit or slice tests plus stubbed/containerized integration tests, and evaluation tests when output quality matters

## What NOT to do

- No `@SpringBootTest` for domain or application tests — wastes time starting a Spring context when no beans are needed.
- No embedded H2 or other fake relational database — schema and behavior drift from PostgreSQL causes false passes.
- No duplicated coverage across slice, module, and integration layers — each tier tests what only it can prove.
- No `@DirtiesContext` unless absolutely unavoidable — it forces a full context (and container) restart, destroying context caching.
