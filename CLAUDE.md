## Build

```bash
scripts/harness/fast-check               # compile + doc-lint (quick feedback)
./mvnw -q test                           # repo test suite (Docker required)
scripts/harness/full-check               # build + all tests + doc-lint + smoke-startup
scripts/harness/run-app                  # start PostgreSQL + run locally
./mvnw spotless:apply                    # format code (Spotless / Google Java Format)
./mvnw spotless:check                    # check formatting only
```

## Prerequisites
Docker must be running for tests and local development. Tests use Testcontainers (auto-managed). Local development uses a PostgreSQL container via `docker compose up -d`.

### Sandbox: Docker Compose volume workaround
Named Docker volumes may fail in sandbox environments (`path not shared` error). If `docker compose up -d` fails, start PostgreSQL manually instead:
```bash
docker run -d --name template-postgres -p 5433:5432 \
  -e POSTGRES_DB=template -e POSTGRES_USER=template -e POSTGRES_PASSWORD=template \
  --tmpfs /var/lib/postgresql/data postgres:17-alpine
```
Data is ephemeral (tmpfs) but sufficient for development and testing. Stop with `docker rm -f template-postgres`.

## Architecture
Java 25, Spring Boot 4, Spring Data JDBC (no JPA), PostgreSQL, Flyway migrations. Testcontainers for tests, Docker Compose for local dev. Spring Modulith vertical modules. Module boundaries enforced by ApplicationModules.verify(). ArchUnit enforces no-JPA, constructor-injection-only field rules, and internal-class visibility. JWT bearer token auth (HMAC dev, issuer-uri prod). No modules yet — this is a clean greenfield template.

## Module structure
Top-level packages under `nl.jinsoo.template` are business modules (Spring Modulith). See [`.claude/rules/modulith.md`](.claude/rules/modulith.md) for the full module structure, creation checklist, and cross-module rules. Every module must have a contract at `.claude/rules/modules/<module-name>.md`.

## Plans
For non-trivial work, persist a plan to `docs/exec-plans/active/` BEFORE writing code. Use `scripts/harness/new-exec-plan` to scaffold. See [`docs/PLANS.md`](docs/PLANS.md) for full guidance including when to create epics vs. plans. Move completed plans to `docs/exec-plans/completed/`.

## Testing
Every code change must have passing tests. See `.claude/rules/testing.md` for the full test pyramid.

`scripts/harness/full-check` is the MANDATORY final step of every plan. No plan is complete until full-check passes.
OpenAPI drift is part of that contract: keep `docs/generated/openapi.json` committed and refresh it with `scripts/harness/generate-openapi` whenever endpoint behavior changes.

## Audit
After completing code changes for a feature or fix, spawn the `audit` agent to verify compliance with `.claude/rules/` before marking work done. This is mandatory for planned work and strongly recommended for ad-hoc changes.

## Learnings
Before starting work, scan `docs/learnings/LEARNINGS.md` for relevant gotchas.

Append a new entry when:
- A dependency/package/class has moved/renamed from what you expected
- A framework API behaves differently than its docs suggest
- A test fails for config/classpath/init reasons unrelated to code under test
- A fix requires reading source code because docs are wrong or missing

## Git discipline
NEVER commit unless the user explicitly asks. Leave changes staged/unstaged and wait for instruction.
