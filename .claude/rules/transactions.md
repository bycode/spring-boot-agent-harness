---
paths:
  - "src/**/internal/*Facade*.java"
  - "src/**/*Service*.java"
---

# Transaction boundaries

## Where @Transactional goes

Every public method on a Facade or Service class (the module API implementation) must have `@Transactional`. The propagation depends on whether the method needs a database connection:

- **DB writes**: `@Transactional`
- **DB reads only**: `@Transactional(readOnly = true)`
- **No DB access** (pure computation, external service calls, orchestration): `@Transactional(propagation = Propagation.NOT_SUPPORTED)`

The deciding question is: **does this method (or any delegate it calls) acquire a JDBC connection?** If yes, use `readOnly` or default propagation. If no — whether it's a pure in-memory calculation, an LLM call, an HTTP request, or orchestration that delegates DB work to other Spring beans — use `NOT_SUPPORTED` to avoid holding a pooled connection for nothing.

Import: `org.springframework.transaction.annotation.Transactional` (not `jakarta.transaction.Transactional`).

## External calls and transaction scope

**Never hold a database connection during an external call.** With virtual threads, `@Transactional` acquires a HikariCP connection for the method's entire duration. If the method calls an LLM (5-30s), HTTP API, Elasticsearch, or message broker, the connection is held idle the entire time. Under modest concurrency this exhausts the pool and stalls the entire application.

Use `Propagation.NOT_SUPPORTED` on facade methods that orchestrate external calls. Sub-operations that need a transaction (e.g., a persistence adapter's `save()`) manage their own via Spring Data JDBC's implicit per-statement transactions or their own `@Transactional` annotation.

```java
// BAD: holds DB connection during 10-30s LLM + HTTP orchestration
@Transactional
public Dossier assembleDossier(UUID conversationId) {
    var facts = conversationApi.getFactState(conversationId);  // DB via another module
    var analysis = llmPort.analyze(facts);                      // 10s+ LLM call — connection held!
    return persistencePort.save(new Dossier(analysis));          // DB
}

// GOOD: no connection held during orchestration; each DB call manages its own
@Transactional(propagation = Propagation.NOT_SUPPORTED)
public Dossier assembleDossier(UUID conversationId) {
    var facts = conversationApi.getFactState(conversationId);  // own transaction
    var analysis = llmPort.analyze(facts);                      // no connection held
    persistencePort.save(new Dossier(analysis));                 // own transaction
    return dossier;
}
```

**Decision criteria — check in this order:**
1. **Mixed DB + external calls?** → `Propagation.NOT_SUPPORTED` on the facade. Move external calls outside transactional boundaries. DB sub-operations manage their own transactions (via Spring Data JDBC defaults or explicit `@Transactional` on adapter methods). When multiple DB operations must be atomic, group them in a single `@Transactional` sub-method — do not rely on separate sub-operations for work that must commit or rollback together.
2. **External calls only, or pure computation with no I/O?** → `Propagation.NOT_SUPPORTED` (no connection needed)
3. **DB reads only?** → `@Transactional(readOnly = true)`
4. **DB writes?** → `@Transactional`

## Event listeners (`@ApplicationModuleListener`)

`@ApplicationModuleListener` is a composed annotation: `@Async` + `@TransactionalEventListener` + `@Transactional(propagation = REQUIRES_NEW)`. This means:

- **Handlers always start a fresh transaction** on a separate virtual thread, not the publisher's thread or transaction.
- The facade-level `@Transactional` rules still apply to whatever the handler delegates to. If the handler calls an external service, the same connection-holding risk applies — use `NOT_SUPPORTED` on the orchestrating method.
- **Pool pressure under fan-out**: each async handler acquires its own connection. High event throughput with many listeners can exhaust the pool. Consider `@ConcurrencyLimit` (see below) on event handler beans if fan-out is high.

## Connection pool admission control

`Propagation.NOT_SUPPORTED` reduces how long connections are held (scope reduction). `@ConcurrencyLimit` (Spring Framework 7, `org.springframework.resilience.annotation`) caps how many concurrent method invocations can run (admission control). Together they address connection pool exhaustion under virtual threads.

Use `@ConcurrencyLimit` on facade or event handler methods that hit the database to ensure concurrent connection demand stays below pool size. Requires `@EnableResilientMethods` on a `@Configuration` class.

## Why NOT on use cases

This template keeps use cases as plain Java objects for framework-free testability. They are instantiated with `new` inside `@Configuration` classes:

```java
// OrderModuleConfiguration.java
var createUseCase = new CreateOrderUseCase(persistence, inventoryAPI);
return new OrderFacade(createUseCase, findUseCase);  // ← Spring bean
```

`@Transactional` relies on Spring AOP proxies. Spring only creates proxies for beans it manages. Since use cases are created with `new`, any `@Transactional` on them is **silently ignored** — no error, no warning, no transaction.

The Facade/Service is returned from a `@Bean` method, so Spring wraps it in a proxy and `@Transactional` works.

This is a design tradeoff. An equally valid approach is making use cases Spring beans (`@Component`) and putting `@Transactional` directly on them. This template chose framework-free use cases, so the Facade carries the transaction boundary.

The `useCasesMustNotHaveTransactionalMethods` ArchUnit rule in `ArchitectureRulesTest` enforces that no `*UseCase` class has `@Transactional` methods. The build fails if someone adds the annotation where it would be silently ignored.

## Transaction propagation

Spring's default propagation is `REQUIRED`: nested calls join the outer transaction. For example, if `OrderFacade.create()` calls `InventoryAPI.reserve()`, the reservation joins the order's transaction. If the order save fails after the reservation, both roll back.

## Pitfalls

- **Self-invocation bypass**: calling another method on `this` within the same class skips the proxy. Each public method needs its own `@Transactional` annotation.
- **Only RuntimeExceptions roll back** by default. This codebase only throws runtime exceptions, so the default is correct.
- **readOnly = true** is an optimization hint to the JDBC driver and PostgreSQL (enables read-only transaction mode), not enforcement.

## Enforcement

The `moduleApiImplementationsMustHaveTransactionalMethods` ArchUnit rule in `ArchitectureRulesTest` enforces that every public method on a module API implementation has `@Transactional`. The build fails if a method is missing the annotation.
