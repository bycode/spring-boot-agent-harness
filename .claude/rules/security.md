---
paths:
  - "src/**/security/**"
  - "src/**/SecurityConfig*"
  - "src/main/resources/application*.yaml"
---

# Security and reliability

## Security posture
- Explicit `SecurityFilterChain` — never fall back to framework defaults
- Stateless sessions (`SessionCreationPolicy.STATELESS`), CSRF disabled
- JWT bearer token auth via OAuth2 Resource Server
- CORS enabled for local browser clients on `/api/**` (configurable via `cors.allowed-origins`)
- `/actuator/health`, `/actuator/info`, `/v3/api-docs/**`, `/swagger-ui/**` are public; all other endpoints require auth
- OpenAPI/Swagger UI disabled in prod profile (`springdoc.*.enabled=false`)
- Dev: HMAC signing key (`jwt.secret-key`), token via `scripts/generate-token.sh`
- Prod: external IdP via `spring.security.oauth2.resourceserver.jwt.issuer-uri`
- Problem Details enabled — API errors use `ProblemDetail` responses (RFC 9457)

## Security rules
- Production secrets via environment variables, never hardcoded
- Security and HTTP behavior stay out of domain/use-case code
- When changing session, CSRF, or auth behavior: update docs and validation expectations
- Keep public monitoring endpoints narrow
- Preserve the explicit security configuration model on extension

Enforcement: scripts/harness/lib/scrub-secrets.sh, invoked by scripts/harness/run-cmd, redacts AWS access keys, GitHub tokens, JWTs, Bearer headers, AWS_SECRET_ACCESS_KEY env assignments, and PEM private-key blocks from subprocess output before emission to the agent. Raw output is preserved in target/runner.log for local debugging. Allowlist for known test fixtures lives at scripts/harness/lib/scrub-secrets-allowlist.txt.

## Runtime baseline
- Dev profile: `localhost:8080`, PostgreSQL on `localhost:5433` (via Docker Compose)
- Prod profile: datasource via `DB_URL`, `DB_USER`, `DB_PASSWORD`; port via `PORT` or `8080`
- PostgreSQL everywhere — never fall back to an embedded database

## Health and observability
- `/actuator/health` is the smoke-check endpoint
- Only `health` and `info` are exposed — keep the operational surface narrow

## Completion standard
- Passing tests alone are not enough — the app must boot with real wiring
- `scripts/harness/full-check` is the canonical validation command
- Docker is required for all test and dev flows
