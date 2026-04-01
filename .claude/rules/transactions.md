---
paths:
  - "src/**/internal/*Facade*.java"
  - "src/**/*Service*.java"
---

# Transaction boundaries

## Where @Transactional goes

Every public method on a Facade or Service class (the module API implementation) must have `@Transactional`:

- **Write methods**: `@Transactional`
- **Read methods**: `@Transactional(readOnly = true)`
- **Orchestration methods** (call LLM, HTTP APIs, or other external services): `@Transactional(propagation = Propagation.NOT_SUPPORTED)`

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

**Decision criteria:**
- Method only does DB reads/writes → `@Transactional` or `@Transactional(readOnly = true)`
- Method calls any external service (LLM, HTTP, search engine, message broker) → `Propagation.NOT_SUPPORTED`
- Mixed: if external calls are unavoidable inside a transaction, keep the transaction as narrow as possible and move external calls outside

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

## Transaction propagation

Spring's default propagation is `REQUIRED`: nested calls join the outer transaction. For example, if `OrderFacade.create()` calls `InventoryAPI.reserve()`, the reservation joins the order's transaction. If the order save fails after the reservation, both roll back.

## Pitfalls

- **Self-invocation bypass**: calling another method on `this` within the same class skips the proxy. Each public method needs its own `@Transactional` annotation.
- **Only RuntimeExceptions roll back** by default. This codebase only throws runtime exceptions, so the default is correct.
- **readOnly = true** is an optimization hint to the JDBC driver and PostgreSQL (enables read-only transaction mode), not enforcement.

## Enforcement

The `moduleApiImplementationsMustHaveTransactionalMethods` ArchUnit rule in `ArchitectureRulesTest` enforces that every public method on a module API implementation has `@Transactional`. The build fails if a method is missing the annotation.
