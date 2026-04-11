---
paths:
  - "src/**/*.java"
  - "pom.xml"
---

# Virtual threads anti-patterns

Virtual threads are enabled (`spring.threads.virtual.enabled=true`). Java 25 resolved carrier thread pinning (JEP 491). The remaining concern is bounded resource exhaustion — primarily the JDBC connection pool.

## Do NOT

- **Create fixed thread pools for IO-bound work.** No `Executors.newFixedThreadPool()`, `newCachedThreadPool()`, or custom `TaskExecutor` beans with fixed pool sizes for IO tasks. Virtual threads handle IO concurrency — a fixed pool limits it artificially. CPU-bound work (image processing, heavy computation) is the only valid use case for platform thread pools.

- **Use `@Async` with custom executors for IO work.** The default virtual thread executor is correct. Do not create `@Bean TaskExecutor` for async IO methods. Only override the executor for CPU-bound tasks that must not monopolize carrier threads.

- **Add custom `ThreadLocal` for request-scoped state.** Virtual threads are cheap and numerous — custom ThreadLocals create far more instances than with platform threads, causing memory pressure. Use Spring's built-in context propagation: `RequestAttributes`, `SecurityContextHolder`, MDC. `ScopedValue` (Java 25 preview) is not used in this project.

- **Use reactive / WebFlux patterns for non-blocking IO.** Blocking is fine on virtual threads — that is the entire point. Do not introduce `Mono`, `Flux`, `CompletableFuture.supplyAsync()`, or callback-based patterns to "avoid blocking." Write straightforward synchronous code.

- **Hold a JDBC connection during external calls.** See `transactions.md` — use `Propagation.NOT_SUPPORTED` on facade methods that orchestrate external service calls (LLM, HTTP, message broker). Virtual threads make this critical: thousands of concurrent requests can each hold a connection, exhausting the pool in seconds.

Nudge: scripts/harness/lib/hook-checks.sh::check_style_scan — PostToolUse hook flags `Executors.newFixedThreadPool(`, `Executors.newCachedThreadPool(`, `CompletableFuture.supplyAsync(`, `ThreadLocal.withInitial(`, and `import reactor.core.publisher.(Mono|Flux)` in any `src/main/java/**/*.java` file.

## Do

- Write synchronous, blocking code for IO. Let virtual threads handle the concurrency.
- Use `@ConcurrencyLimit` (Spring Framework 7 resilience) on methods that access bounded resources. See `transactions.md` § "Connection pool admission control."
- Keep HikariCP pool size small (default 10 is a reasonable starting point). The pool is the concurrency bottleneck by design — tune it, do not remove it.
