# Codex Contract

This repository is an agent-first template for Java 25 / Spring Boot 4 backends built around Spring Modulith, Spring Data JDBC, Flyway, PostgreSQL, Testcontainers, and deterministic validation.

This file is the Codex entrypoint. It is additive to the existing Claude setup in [CLAUDE.md](CLAUDE.md) and `.claude/`. Do not edit, remove, or contradict the Claude files when working from this Codex layer.

## Start Here
- Read [README.md](README.md) for onboarding, quick-start commands, and the current template surface.
- Read [ARCHITECTURE.md](ARCHITECTURE.md) for the current code, runtime, and validation topology.
- Read [Design Docs Index](docs/design-docs/index.md) for the durable Codex-facing knowledge map.
- Read [ADR-001-v2-agent-first-modularity.md](docs/architecture/decisions/ADR-001-v2-agent-first-modularity.md) for the governing architecture decision.
- Read [LEARNINGS.md](docs/learnings/LEARNINGS.md) before working in areas with framework, testing, or build-tool gotchas.
- Read [PLANS.md](docs/PLANS.md) before creating or updating durable execution plans.
- Use [docs/exec-plans/active](docs/exec-plans/active) and [docs/exec-plans/completed](docs/exec-plans/completed) as the durable work log for non-trivial changes.

## Canonical Commands
Preferred Codex harness entrypoints:
- `scripts/harness/fast-check`
- `scripts/harness/full-check`
- `scripts/harness/run-app`
- `scripts/harness/smoke-startup`
- `scripts/harness/doc-lint`
- `scripts/harness/new-exec-plan`
- `scripts/harness/new-module`

Underlying repo commands:
- `./mvnw -q compile`
- `./mvnw -q test`
- `./mvnw -q verify`
- `docker compose up -d`
- `./mvnw spring-boot:run`
- `./mvnw spotless:apply`
- `./mvnw spotless:check`

Docker is required for tests and local development. Local development uses `docker compose`, while tests use Testcontainers. In sandboxed environments, `docker compose` may need the documented manual `docker run` fallback, and SpotBugs may require `-Dspotbugs.skip=true`.

## Working Rules
- Treat top-level packages under `nl.jinsoo.jurido` as business modules. The root package of a module is its public API; `internal/`, `persistence/`, and `rest/` are hidden implementation details.
- Keep current architectural constraints intact: Spring Data JDBC only, Flyway-only schema changes, no JPA, no mapping frameworks, constructor injection only, thin controllers, and framework-free domain/use-case code.
- Every `package-info.java` must have `@org.jspecify.annotations.NullMarked`. Use `@Nullable` only where null is genuinely part of the contract. NullAway enforces at compile time.
- Use the current test pyramid and Spring Boot 4 testing APIs. Do not regress to deprecated patterns such as `@MockBean`, `TestRestTemplate`, raw `MockMvc`, or embedded H2 shortcuts.
- Never commit unless the user explicitly asks.
- When a path-local `AGENTS.md` exists, it refines these root rules for its subtree.

## Transaction Boundaries
- Every public method on a Facade or Service class (the module API implementation) must have `@Transactional`. Write methods get `@Transactional`, read methods get `@Transactional(readOnly = true)`, orchestration methods that call external services (LLM, HTTP APIs, Elasticsearch) get `@Transactional(propagation = Propagation.NOT_SUPPORTED)`.
- **Never hold a DB connection during an external call.** With virtual threads, a wide `@Transactional` scope acquires a HikariCP connection for the full method duration. If the method calls an LLM or HTTP API (seconds to minutes), the connection is held idle, exhausting the pool under modest concurrency. Use `Propagation.NOT_SUPPORTED` for orchestration methods; let sub-operations manage their own transactions.
- **Never put `@Transactional` on UseCase classes.** Use cases are plain Java objects created with `new` in `@Configuration` classes — Spring AOP does not intercept them, so the annotation is silently ignored.
- The Facade/Service is the Spring bean (returned from `@Bean`), so `@Transactional` works there.
- Import: `org.springframework.transaction.annotation.Transactional` (not `jakarta.transaction.Transactional`).
- Enforced by the `moduleApiImplementationsMustHaveTransactionalMethods` ArchUnit rule — the build fails if a method is missing the annotation.

## Planning And Durable Memory
- For multi-file or architectural work, persist the approved plan in [docs/exec-plans/active](docs/exec-plans/active) before editing. If the work spans multiple plans, create the `EPIC-NNNN` file first.
- Keep plan files current: update checklist state, append decision-log entries for meaningful trade-offs, and record tech debt when introduced.
- Move completed plans from `active/` to `completed/` when their work is actually finished.
- Add or update learnings in [LEARNINGS.md](docs/learnings/LEARNINGS.md) when framework behavior, tool behavior, or debugging effort reveals reusable repo knowledge.

## Completion Criteria
- Every production change must be backed by the appropriate tests for its layer.
- `./mvnw -q verify` is the mandatory final validation command.
- After `verify`, confirm runtime startup with `docker compose up -d && ./mvnw spring-boot:run` and wait for a successful start.
- Keep Codex-facing docs aligned with the same standards already configured for Claude; the Codex layer must not weaken the existing architecture, planning, or validation rules.
