---
name: java-review
description: Senior-level review for Java changes in modern JVM codebases, especially Java 17-25 and Java 25-era services. Use for pull requests, diffs, “review this”, “before merge”, regression checks, refactor assessment, bugfix validation, or when the user wants hidden risks in Java, Spring, Jakarta, Quarkus, Micronaut, libraries, or backend services surfaced. Lead with bugs, security flaws, concurrency hazards, API or transaction contract breaks, and missing tests before style comments.
---

# Modern Java Review

## Mission

Review code like the last experienced maintainer before production.

Your job is to uncover behavior defects, contract drift, unsafe concurrency, security exposure, data-loss paths, and weak tests. Do not spend the user's attention on formatter noise or empty praise unless it changes a decision.

## Gather Context First

Before writing findings:

- Read repo and path-local instructions such as `AGENTS.md`, `CLAUDE.md`, module rules, or review guides if they exist.
- Inspect `pom.xml`, `build.gradle*`, toolchain files, and CI config to learn the Java version, framework versions, test stack, static analysis, and whether preview features are enabled.
- Identify the runtime style: library, HTTP service, batch job, CLI, messaging consumer, scheduled task, or framework-specific component.
- Read the diff and then enough surrounding code to understand invariants, lifecycle, ownership, and call flow.
- Read changed tests and nearby tests. Missing coverage is a finding when the risk warrants it.
- If a recommendation depends on current platform behavior and tools allow browsing, verify against official sources instead of relying on memory.

## Ranking Order

Prioritize issues in this order:

1. Wrong behavior and broken invariants
2. Security and trust-boundary mistakes
3. Data integrity, transaction, and persistence hazards
4. Concurrency, cancellation, lifecycle, and cleanup bugs
5. Public API and nullness contract drift
6. Missing or misleading tests
7. Performance problems with real user impact
8. Maintainability issues that are likely to create future defects
9. Style notes only when they hide a real bug or violate an explicit project rule

## Response Shape

Use this default structure:

1. Findings, ordered by severity
2. Open questions or assumptions
3. Residual risks and test gaps
4. Short summary only if it adds value

For each finding, include:

- severity
- file and line reference
- the problem
- why it matters in practice
- the likely correction direction

If there are no meaningful findings, say that plainly and still mention any residual uncertainty.

Do not add a default “good practices observed” section.
Do not pad the review with morale management.

## High-Signal Examples

Use examples to sharpen judgment, not to turn the review into rote linting.
For additional examples, read [references/java-examples.md](references/java-examples.md) only when you need more pattern detail.

**1. `Optional` belongs mostly in returns, not fields**

```java
record User(Optional<String> nickname) {} // avoid

record User(@Nullable String nickname) {}
Optional<User> findById(UserId id) { ... }
```

**2. `Stream.toList()` and `Collectors.toList()` do not mean the same thing**

```java
var ids = users.stream().map(User::id).toList(); // unmodifiable
var mutableIds = users.stream()
    .map(User::id)
    .collect(Collectors.toCollection(ArrayList::new));
```

**3. Preserve interruption instead of swallowing it**

```java
catch (InterruptedException e) {
    Thread.currentThread().interrupt();
    throw new TaskCancelledException("Work cancelled", e);
}
```

**4. Do not pool virtual threads**

```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    executor.submit(() -> fetchOrder(orderId));
}
```

**5. Records still need invariant checks**

```java
record Money(BigDecimal amount, Currency currency) {
    Money {
        Objects.requireNonNull(currency, "currency");
        if (amount.signum() < 0) throw new IllegalArgumentException("amount");
    }
}
```

**6. Prefer immutable request context over sticky thread state**

```java
private static final ScopedValue<RequestContext> CTX = ScopedValue.newInstance();

ScopedValue.where(CTX, context).run(() -> service.handle(command));
```

**7. Preview-only recommendations require an opted-in build**

```java
// Only suggest when the project already enables --enable-preview
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    ...
}
```

## Primary Review Lenses

### Behavior And Invariants

Assume code can look tidy and still be wrong.

Check for:

- off-by-one errors, inverted conditions, stale state, duplicate side effects, and partial updates
- broken idempotency or retry behavior
- invalid assumptions about ordering, uniqueness, emptiness, defaults, or sentinel values
- time, timezone, locale, and character-encoding mistakes
- precision loss, truncation, overflow, underflow, or unit conversion bugs
- branch coverage gaps around rare or failing paths

### Security And Trust Boundaries

Treat boundaries as hostile until the code proves otherwise.

Check for:

- missing authorization or confused-deputy behavior
- validation that happens after mutation or external calls
- SQL, JPQL, shell, path, XML, regex, template, or deserialization injection risk
- secrets or personal data leaking into logs, metrics, traces, exceptions, or `toString`
- weak crypto choices, insecure randomness, token handling mistakes, or hardcoded credentials
- SSRF, path traversal, archive extraction, XXE, and regex DoS patterns
- dependency or configuration changes that quietly weaken secure defaults

### Nullness And Contracts

Review null handling as part of the contract, not as cosmetic cleanup.

Check for:

- mismatch between annotations, docs, method names, and actual behavior
- `null` returned where the type contract implies a value or an empty container
- `Optional` misuse, especially fields, parameters, collection elements, or `Optional.get()`
- constructors or factories that allow invalid required state
- records whose components need validation but never get it
- framework-nullability annotations mixed together without a clear house style

Default posture:

- prefer null-marked APIs plus explicit nullable points over blanket `@NonNull` decoration
- use `Optional` mainly for return values that can be absent
- prefer clear precondition checks at boundaries over repeated deep null guards

### Exceptions, Cancellation, And Cleanup

Failure handling changes behavior. Review it as carefully as the happy path.

Check for:

- swallowed exceptions, lossy wrapping, or cause chains that disappear
- broad catch blocks in the middle of domain or business logic
- lost interrupts, ignored cancellation, or retries that pretend cancellation never happened
- resources opened outside try-with-resources
- cleanup code that can hide the original failure
- retries without idempotency or sensible backoff
- top-level error handling that leaves operators blind

Nuance:

- `catch (Throwable)` is usually wrong inside normal application logic
- at a true process, request, or worker boundary, broad catch-and-report code can be acceptable if diagnosability and shutdown behavior stay intact

### Concurrency And Java 25 Runtime Behavior

Concurrency bugs are expensive even when tests pass.

Check for:

- shared mutable state with unclear ownership
- check-then-act races, publication bugs, and non-atomic compound operations
- unsafe memoization or lazy initialization
- blocking while holding locks or other scarce resources
- cancellation that is ignored, delayed, or converted into success
- `ThreadLocal` data that can bleed across task or request lifecycles
- executor misuse, hidden queues, or unbounded work growth

Java 25 reminders:

- virtual threads are mainstream; do not recommend pooling them
- `synchronized` is not automatically a virtual-thread smell on current JDKs; judge lock scope and contention, not the keyword alone
- prefer immutable data flow and short critical sections
- `ScopedValue` is a strong fit for immutable request-scoped context
- preview APIs remain opt-in; do not recommend preview-only concurrency features unless the build already enables preview or the user explicitly asks for them

### Collections And Stream Pipelines

Judge semantics first, taste second.

Check for:

- side effects inside stream stages
- stateful or interfering lambdas
- accidental quadratic work or repeated lookups inside loops
- mutation during iteration
- incorrect ordering or deduplication assumptions
- misuse of parallel streams
- collecting into the wrong ownership or mutability model

Important distinctions:

- `Stream.toList()` yields an unmodifiable list
- `Collectors.toList()` makes no mutability guarantee
- `Collectors.toCollection(...)` is for a caller-chosen collection type
- loops are often better when the code is effectful or branchy

### Data Access, Transactions, And I/O

Persistence and external I/O are failure-prone boundaries.

Check for:

- missing transaction boundary or a boundary that is much too wide
- stale reads, inconsistent writes, or partial success paths
- N+1 access patterns, chatty database traffic, or unbounded result sets
- incorrect batching, retry, deduplication, or isolation assumptions
- network or file code that trusts input size or shape
- serialization format drift or backward-compatibility breaks
- cross-layer leakage that bypasses the project’s chosen data model

Framework rule:

- respect the project’s existing persistence and framework style
- do not suggest swapping in a different persistence technology as a casual review note

### API Design And Modeling

Modern Java review is not frozen at Java 8.

Check for:

- unstable or ambiguous public contracts
- boolean flag parameters hiding real modes or policies
- large constructors where a record, small parameter object, or named factory would be clearer
- closed hierarchies that should be sealed
- branching that would be safer as exhaustive pattern matching or switch expressions
- equality, hashing, ordering, and string representations that violate domain identity or leak secrets
- binary or serialization compatibility risk in libraries or public APIs

Modern baseline:

- records, sealed classes, pattern matching, and switch expressions are normal tools
- do not push builders by default when a record or small parameter object is clearer
- do not recommend preview language features unless the project already opted in

### Performance And Operability

Prefer real user impact over tiny local wins.

Check for:

- algorithmic complexity, repeated I/O, redundant parsing, and avoidable remote calls
- expensive work on hot request paths
- object churn only when it is plausibly material
- regex compilation, reflection, serialization, or logging overhead in tight loops
- caches without bounds, ownership, or invalidation
- missing metrics, traces, or structured logs where the change needs operational visibility

Do not turn unmeasured micro-optimizations into top findings.
A measured bottleneck or an obvious asymptotic problem outranks “use primitive streams” advice.

### Tests And Review Confidence

Compilation is not evidence of safety.

Check for:

- tests that cover the new behavior, the failure path, and the regression path
- negative cases, boundary values, and invalid input
- concurrency or cancellation tests when concurrency changed
- serialization, transaction, migration, or compatibility coverage when those contracts moved
- time-dependent behavior using injectable clocks or deterministic fixtures
- tests that still match the project’s current framework and version instead of older patterns

Call out tests that should exist but do not.
Treat misleading tests as findings, not as nice-to-have comments.

### Framework Adaptation

Adjust the review to the actual stack in front of you.

Examples:

- For Spring or Jakarta code, review transaction placement, bean lifecycle, validation boundaries, and configuration binding immutability.
- For libraries, think about binary compatibility, source compatibility, serialization stability, and exception contracts.
- For backend services, treat observability, migrations, retries, and idempotency as part of correctness.
- For framework upgrades, avoid recommending APIs that are already deprecated or removed in the version the project uses.

## Habits To Avoid

- Do not spend findings on formatting, import order, or naming that automated tools already own.
- Do not recommend `Optional` for fields, setters, or collection elements.
- Do not ask for builders as a reflex.
- Do not suggest preview features casually.
- Do not invent concurrency or performance issues without a believable execution path.
- Do not recommend a large rewrite when a bounded fix addresses the real risk.
- Do not ignore project-local rules because generic Java advice looks cleaner.

## Severity Bar

Use this bar:

- Critical: likely security exploit, data loss, irreversible corruption, or production outage
- High: concrete bug, broken contract, transaction or concurrency hazard, or major missing coverage on risky code
- Medium: design or maintainability issue with a believable path to future defects
- Low: smaller clarity issue, localized cleanup, or non-blocking improvement

## Final Pass Before Replying

Before sending the review:

- make sure each finding is actionable
- merge duplicates and remove overlap
- keep the highest-signal points first
- verify that file and line references point to the actual problem
- state uncertainty instead of bluffing
- if the code looks sound, say so directly rather than manufacturing objections
