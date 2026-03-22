# spring-boot-agent-harness
A Java 25 / Spring Boot 4 starter for developers who want to work with AI coding agents. The repo ships enforceable rules, module contracts, validation gates, and execution plans that make agents productive instead of dangerous.
OpenAI calls this approach harness engineering: https://openai.com/index/harness-engineering/

Clone it, run `init-template` to make it yours, and start building.

About the choice for vertical slices with Spring Modulith:
Context window management matters for coding agents. Spring Modulith enforces hard module boundaries, an agent only needs the module it's changing plus the public contracts of its
dependencies, not the entire codebase.

## The harness
This one gives you infrastructure for agent-assisted development, while also making some very opinionated Spring Boot choices:

- **`.claude/rules/`** path-based rules, automatically injected whenever relevant files are touched. Unlike subagents or skills, these don't need to be explicitly invoked.
- **Module contracts** (`.claude/rules/modules/`) pin ownership, public API, dependencies, and validation commands per module. Agents know what's off-limits
- **Audit agent** reviews code against rules after changes. Skips what the compiler and linters already enforce
- **Harness scripts** (`full-check`, `fast-check`, `new-module`) give agents deterministic validation — green or red, no "looks good to me"
- **Execution plans** (`docs/exec-plans/`) persist multi-step work so agents resume across sessions without losing context
- **Learnings** (`docs/learnings/`) accumulate framework gotchas. Agents check before starting work

Optimized for [Claude Code](https://claude.com/claude-code). Works with Codex via `AGENTS.md`.

## The stack
- **Java 25 + Spring Boot 4** — Virtual threads enabled
- **Spring Modulith** — Vertical modules with boundaries enforced at build time
- **JSpecify + NullAway** — Null safety at compile time via Error Prone
- **ArchUnit** — Architecture conventions as build failures
- **Quality gates** — Spotless, PMD, SpotBugs, JaCoCo, OpenAPI drift detection
- **Reference module** — Full notes CRUD demonstrating the module structure at every test tier

Interchangeable (just realistic filler — could be swapped for anything):
* Spring Data JDBC, PostgreSQL + Flyway, JWT auth

## Prerequisites

**Docker** must be running (PostgreSQL runs in a container).

**Java 25** via [SDKMAN!](https://sdkman.io):

```bash
curl -s "https://get.sdkman.io" | bash
sdk install java 25-open
```

Maven is included via the wrapper (`./mvnw`).

## Quick start

```bash
git clone <repo-url> && cd spring-boot-agent-harness
scripts/harness/run-app
```

Starts PostgreSQL and the app. Open [Swagger UI](http://localhost:8080/swagger-ui.html) to try the notes API.

## Make it yours

Rewrites packages, Maven coordinates, Docker config, and removes the sample notepad module:

```bash
scripts/harness/init-template \
  --group-id com.yourorg \
  --artifact-id your-service \
  --base-package com.yourorg.yourservice
```

Use `--dry-run` to preview changes first.

## Development

```bash
scripts/harness/fast-check           # Compile + doc-lint
./mvnw -q verify                     # Tests + quality gates
scripts/harness/full-check           # Verify + smoke startup + OpenAPI drift check
./mvnw spotless:apply                # Auto-format code
scripts/harness/new-module           # Scaffold a new module
```

## Learn more

- [ARCHITECTURE.md](ARCHITECTURE.md) for module structure, persistence rules, and test pyramid
- [CLAUDE.md](CLAUDE.md) for [Claude Code](https://claude.com/claude-code) integration
- [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md) for the engineering principles behind the choices

## License

[MIT](LICENSE)
