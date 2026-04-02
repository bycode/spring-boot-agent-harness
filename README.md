# spring-boot-agent-harness
A Java 25 / Spring Boot 4 starter for developers who want to experiment with AI coding agents and who are interested in harness engineering (https://openai.com/index/harness-engineering/). I created this repo with these goals in mind:
1. Check what Codex / Claude code is capable of with Java 25, Spring boot 4+ and Spring ai 2+
2. Check how we can enforce Codex / Claude code to adhere to our rules consistently, not only by providing native solutions (like Claude code rules, skills, agents, hooks) but also enforce rules via the harness described below.

   So far path based rules look promising to make sure rules are always present in the context window when relevant.
3. Find an optimal architecture that is suitable for agentic coding, where we want to keep context windows as clean as possible. Vertical slices + Spring Modulith look really promising so far.

The non-goals:
1. While finding an optimal architecture can be a real result for agentic coding, this repo is NOT meant as a best practice.
2. I am mainly interested in if/how Codex / Claude code is able to adhere to what it is instructed, not what the instruction itself exactly is (looking at code-style, testing etc.)

If you have questions, you can always approach me here: https://nl.linkedin.com/in/hanno-brinkman-9847a636

Clone it, run `init-template` to make it yours, and start building.

## The "harness"
It gives you infrastructure for agent-assisted development, while also making some very opinionated Spring Boot choices.

### Maven wrapper (`scripts/harness/mvn`)

Wraps all Maven invocations for minimal, high-signal output. On success it prints a one-liner; on failure it extracts `[ERROR]` lines from the console **and** reads structured build artifacts (`target/surefire-reports`, `target/failsafe-reports`) to surface assertion messages that
Maven's `-q` mode never prints to the console. Full unfiltered output from the last run is available at `target/runner.log`.

### Infrastructure

- **Path-based rules** (`.claude/rules/`) — automatically injected whenever relevant files are touched. Unlike subagents or skills, these don't need to be explicitly invoked.
- **Module contracts** (`.claude/rules/modules/`) — pin ownership, public API, dependencies, and validation commands per module. Agents know what's off-limits.
- **Audit agent** — reviews code against rules after changes. Skips what the compiler and linters already enforce.
- **Harness scripts** (`full-check`, `fast-check`, `new-module`) — give agents deterministic validation. Green or red, no "looks good to me."
- **Execution plans** (`docs/exec-plans/`) — persist multi-step work so agents resume across sessions without losing context.
- **Learnings** (`docs/learnings/`) — accumulate framework gotchas. Agents check before starting work.

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
