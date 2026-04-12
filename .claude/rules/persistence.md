---
paths:
  - "src/**/persistence/**"
  - "src/main/resources/db/migration/**"
---

# Persistence adapter rules

Implements port interfaces from `internal`. Translates between domain models and database representations.

## Spring Data JDBC

Production code uses repository interfaces, not JdbcClient.

| Complexity | Approach |
|---|---|
| Simple CRUD | `CrudRepository` / `ListCrudRepository` |
| Simple filters (up to ~3 params, no JOINs) | Derived query methods |
| Complex queries (JOINs, aggregations) | `@Query` with native SQL |
| Batch operations, stored procedures | `JdbcTemplate` alongside repository |

JdbcClient and JdbcTemplate are allowed in production code only for batch/stored-proc use cases, and in test fixture setup code.

## Entity mapping

Use static factory methods on records. Direction: toward domain at inbound, away from domain at outbound.

```java
@Table("orders")
public record OrderEntity(@Id Long id, String customerId, String status) {
    public static OrderEntity from(Order order) { /* domain -> entity */ }
    public Order toDomain() { /* entity -> domain */ }
}
```

- Simple entities: `@Table`/`@Id`/`@Column` annotations on the persistence entity record.
- When domain model is simple and team accepts it: Spring Data JDBC can work directly with annotated domain types.
- Switch to separate persistence entity when: schema diverges from domain, multiple adapters, complex aggregates needing flattening.
- For 10+ fields or conditional logic: dedicated `<Entity>Mapper` utility class (final, static methods, one per aggregate root).

## Schema management — Flyway

> **One-time setup after cloning:** run `scripts/harness/install-git-hooks` to install the pre-commit guard that blocks edits to applied migrations. The guard delegates to `check_migration_edit_guard` in `scripts/harness/lib/hook-checks.sh`.

All schema changes are managed by Flyway migrations. Never use `schema.sql` for DDL.

- Migrations live in `src/main/resources/db/migration/`
- Naming: `V{n}__description.sql` (double underscore, snake_case description, e.g., `V1__create_orders_table.sql`)
- Never edit a migration that has been applied — always create a new one
- Use PostgreSQL-native types: `BIGSERIAL` for auto-generated IDs, `TEXT` for unbounded strings, `TIMESTAMPTZ` for timestamps
- Use lowercase column names in DDL — Spring Data JDBC quotes identifiers, and PostgreSQL is case-sensitive for quoted identifiers

Enforcement: scripts/harness/lib/hook-checks.sh::check_migration_edit_guard — blocking pre-commit guard that refuses commits containing modifications (not additions) to files under src/main/resources/db/migration/. Install once per clone with `scripts/harness/install-git-hooks`; the installer is idempotent and preserves any pre-existing .git/hooks/pre-commit content. Override for the rare legitimate rename with `git commit --no-verify` and document the rationale in the plan's decision log.

## PostgreSQL + Spring Data JDBC notes

- `BIGSERIAL` maps to `Long` with `@Id` — PostgreSQL handles auto-increment via sequences
- Spring Data JDBC treats entities with non-null `@Id` as existing (triggers UPDATE). For pre-assigned IDs, add `@Version Integer version` (pass `null` for new entities)
- PostgreSQL does not auto-uppercase identifiers (unlike H2) — use lowercase consistently in DDL and `@Table`/`@Column` annotations

## Error handling

Wrap infrastructure exceptions only when they have domain meaning:

```java
try { return repository.save(order); }
catch (DuplicateKeyException e) { throw new OrderAlreadyExistsException(order.id()); }
// Let other DataAccessExceptions propagate to the catch-all handler
```

## Aggregate save behaviour

`repository.save()` on an aggregate with child collections does DELETE ALL + INSERT ALL for children on every save. This is by design — the aggregate is the consistency boundary. If this causes performance problems, the aggregate is too large — split it.

## Concurrency

### Mutation return types — avoid check-then-act

Port methods that mutate a single entity must return enough information for the caller to know whether the operation took effect. This prevents TOCTOU race conditions where a separate existence check becomes stale before the mutation executes.

| Operation | Return type | Meaning |
|-----------|-------------|---------|
| Delete one entity | `boolean` | `true` if a row was deleted |
| Conditional update (by ID) | `boolean` or `Optional<T>` | Whether a row was matched and updated |
| Batch delete/update | `int` | Number of affected rows |

Bad — separate check creates a race window:

    if (!persistence.existsById(id)) throw new NotFoundException(id);
    persistence.deleteById(id); // entity may already be gone

Good — single atomic operation, caller inspects result:

    if (!persistence.deleteById(id)) throw new NotFoundException(id);

At the adapter layer, use `@Modifying @Query` returning `int`, then convert to `boolean`:

    @Modifying @Query("DELETE FROM notes WHERE id = :id")
    int deleteAndReturnCount(long id);

Updates that need the prior state (e.g., merging fields) correctly use `findById` + `save` within a `@Transactional` boundary — the transaction provides atomicity. This rule targets fire-and-forget mutations where only success/failure matters.

### Optimistic locking — prevent lost updates

When concurrent modifications to the same entity must not silently overwrite each other, add `@Version`:

    @Table("orders")
    public record OrderEntity(@Id Long id, @Version Integer version, ...) { }

How it works: Spring Data JDBC adds `WHERE version = :v` to UPDATE and DELETE statements. If another transaction changed the row, the version won't match, and Spring throws `OptimisticLockingFailureException`.

| Scenario | Use optimistic locking? |
|----------|------------------------|
| Last-writer-wins is acceptable (simple PUT replace) | No — adds complexity for no benefit |
| Concurrent edits must not silently overwrite each other | Yes |
| Entity has a version/updated_at column already | Consider it — low cost to add |
| High-contention entities (inventory, balances) | Yes, or pessimistic locking for extreme cases |

Schema: add `version INTEGER NOT NULL DEFAULT 0` via Flyway migration.

Domain impact: the `version` field appears on the persistence entity only. Do not leak it into domain records unless the domain genuinely needs conflict detection (e.g., exposing `ETag` headers). Map it away in `toDomain()`.

Catch `OptimisticLockingFailureException` in the adapter or facade and translate to a domain exception (e.g., `StaleEntityException`) when the caller needs to distinguish conflicts from other errors.

## What NOT to do

- No mapping in domain or application code. Domain does not know about entities or DTOs.
- No passing DTOs through use cases. Convert to domain types at the boundary.
- No shared mapper modules across adapters. Each adapter owns its mapping.
- No `void` return on port methods that delete or conditionally update. Return `boolean` or a count so callers detect no-ops without a separate existence check.
