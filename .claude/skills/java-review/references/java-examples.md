# Java Review Examples

Use this file only when the main skill needs a few concrete patterns to calibrate judgment.
Do not dump these examples into every review.

## Nullness And API Contracts

**Return absence, do not parameterize with `Optional`:**

```java
void send(Optional<String> email) { ... } // avoid
Optional<String> findEmail(UserId userId) { ... }
```

**Null-mark the actual contract edge:**

```java
@Nullable String middleName()
```

Prefer a small number of explicit nullable points over annotation spam.

## Streams And Mutability

**Caller expects mutation:**

```java
var names = users.stream()
    .map(User::name)
    .collect(Collectors.toCollection(ArrayList::new));
```

**Caller expects a snapshot:**

```java
var names = users.stream().map(User::name).toList();
```

Treat the mutability choice as part of the API contract.

## Cancellation

**Do not convert cancellation into success:**

```java
catch (InterruptedException e) {
    return Result.success(); // wrong
}
```

**Preserve the signal:**

```java
catch (InterruptedException e) {
    Thread.currentThread().interrupt();
    throw new TaskCancelledException("Interrupted", e);
}
```

## Virtual-Thread Era Review

**Do not fix blocking fan-out by making a giant platform-thread pool:**

```java
ExecutorService exec = Executors.newFixedThreadPool(1000); // suspicious
```

**Prefer a virtual-thread-per-task executor when that runtime model fits:**

```java
try (var exec = Executors.newVirtualThreadPerTaskExecutor()) {
    ...
}
```

Still review lock scope, remote-call limits, backpressure, and cancellation behavior.

## Request Context

**Sticky thread state:**

```java
private static final ThreadLocal<RequestContext> CTX = new ThreadLocal<>();
```

**Scoped immutable context:**

```java
private static final ScopedValue<RequestContext> CTX = ScopedValue.newInstance();
```

This is especially relevant when context should flow into a bounded call tree instead of lingering on reused threads.

## Records And Invariants

**Concise model, missing validation:**

```java
record Money(BigDecimal amount, Currency currency) {}
```

**Compact constructor with guardrails:**

```java
record Money(BigDecimal amount, Currency currency) {
    Money {
        Objects.requireNonNull(amount, "amount");
        Objects.requireNonNull(currency, "currency");
        if (amount.signum() < 0) throw new IllegalArgumentException("amount");
    }
}
```

Reviewers should not assume records are valid just because they are concise.

## Findings Style

**Weak review comment:**

```text
Maybe use a different collection here.
```

**Actionable review comment:**

```text
High - FooService.java:42: `Stream.toList()` returns an unmodifiable snapshot, but line 48 appends to it. This will fail at runtime on the first mutation. Collect into `ArrayList` or stop mutating the result.
```

Good review output names the failure mode, impact, and correction direction.
