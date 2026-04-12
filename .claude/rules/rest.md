---
paths:
  - "src/**/rest/**"
---

# REST adapter rules

Inbound HTTP adapter. Owns URI design, transport DTOs, RFC-aligned HTTP semantics, and translation between HTTP and the module API. It does not own business policy. For caching, conditional requests, idempotency, rate limiting, and API versioning details, use the `/rest-reference` skill.

## Spring Boot 4 / Framework 7 specifics

| Concern | Project standard | Notes |
|---------|-----------------|-------|
| Jackson version | Jackson 3 (`tools.jackson`) | Default: alphabetical property order, ISO-8601 dates. `@JacksonComponent` replaces `@JsonComponent` |
| Validation | Native method validation | `@RequestParam` and `@PathVariable` with constraints work without class-level `@Validated` |
| API versioning | Framework 7 built-in | `@GetMapping(version = "1.1")` + `ApiVersionStrategy` — prefer over manual URI/header schemes |
| springdoc-openapi | v3.x | v2.x is for Boot 3; v3.x tracks Boot 4 |
| Converter registration | `ServerHttpMessageConvertersCustomizer` | `HttpMessageConverters` is deprecated |
| Problem details | `application/problem+json` auto-negotiated | Jackson codecs prefer `application/problem+json` for `ProblemDetail` responses |

## Controller responsibilities

- Thin controllers only: bind transport input, apply transport validation, delegate to the module API or facade, map results to HTTP responses.
- No business logic, repository access, transactions, cross-module orchestration, or exception swallowing in controllers.
- Inject the module public API (`<Module>API`) or facade/service bean — never persistence adapters or internal use cases (hidden by Spring Modulith).
- Never put `@Validated` on `@RestController` classes. Spring MVC 7 validates constrained `@RequestParam` and `@PathVariable` natively — adding `@Validated` causes double-validation and misleading error responses.
- Do not special-case authentication or authorization in controllers. Leave 401/403 to Spring Security's exception chain — per-controller auth logic bypasses the security filter chain.

Nudge: scripts/harness/lib/hook-checks.sh::check_style_scan — PostToolUse hook flags any `src/main/java/**/*.java` file that declares both `@RestController` and `@Validated` at the start of a line.

### Return types

| Situation | Return type | Why |
|-----------|-------------|-----|
| Custom status code, `Location` header, or other headers | `ResponseEntity<T>` | Full control over status and headers |
| Simple `200 OK` with a body | Raw `T` (e.g., `NoteResponseDTO`) | Less ceremony — Spring defaults to `200` |
| No response body (`204`, `202`) | `void` + `@ResponseStatus` | Or `ResponseEntity<Void>` if headers are needed |
| `201 Created` with `Location` | `ResponseEntity.created(uri).body(...)` | `Location` is mandatory for `201` |

```java
@PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest request) {
    var created = orderAPI.create(request.toDomain());
    var location = ServletUriComponentsBuilder.fromCurrentRequest()
        .path("/{id}").buildAndExpand(created.id()).toUri();
    return ResponseEntity.created(location).body(OrderResponse.from(created));
}
```

## URI design

- All REST endpoints live under the `/api/` path prefix. Security (CORS, auth rules) and OpenAPI grouping depend on this convention.
- Prefer plural nouns for collection resources: `/api/orders`, not `/api/order`.
- Use kebab-case for multi-word path segments: `/api/line-items`, not `/api/lineItems`.
- Keep nesting shallow — at most one level: `/api/orders/{orderId}/items`. Deeper nesting signals a missing top-level resource.
- Use action endpoints only when no stable resource model fits: `/api/orders/{id}/cancel`.
- CORS is handled centrally in `SecurityConfig` (see `security.md`). Do not use `@CrossOrigin` on controllers — it bypasses the security filter chain and creates inconsistent CORS policies.

Nudge: scripts/harness/lib/hook-checks.sh::check_style_scan — PostToolUse hook flags `@CrossOrigin` at the start of a line in any `src/main/java/**/*.java` file, and also flags any `@(Get|Post|Put|Delete|Patch|Request)Mapping("path")` where `path` does not start with `/api/`.

## Collection endpoints

- Deterministic default ordering is mandatory — unstable ordering breaks pagination and client reconciliation.
- Prefer opaque cursors for large or mutable collections. Offset pagination is acceptable for small bounded datasets and admin UIs. Cursor/keyset is O(1); offset is O(n).
- Document the default and maximum page size in the module contract. Empty collections return `200 OK` with an empty payload, not `204`.

## DTO mapping

- Request DTOs own inbound parsing: `toDomain()` or `toCommand()`. Response DTOs own outbound mapping: `from(...)`.
- Domain types never expose `toResponse()` or `toDto()` — mapping direction always flows away from domain. Domain has no knowledge of its adapter consumers.
- No mapping frameworks. Explicit mappings keep boundaries visible and prevent magic field-name coupling — trivial for record-based DTOs.
- Do not leak persistence-only fields (optimistic-lock versions, internal IDs) into the API. Prefer `ETag` for concurrency.
- Jackson 3 serializes properties alphabetically by default. Design DTOs accordingly — use `@JsonPropertyOrder` only when a specific order is contractual.
- Use `@Valid` for request bodies and Jakarta Validation constraints on parameters. Semantic parsing happens in `toDomain()`, not Bean Validation.

## Error handling — RFC 9457 Problem Details

- Use module-local `@RestControllerAdvice(assignableTypes = <Controller>.class)` with `@Order(Ordered.HIGHEST_PRECEDENCE)` for domain exception mapping.
- Enable globally: `spring.mvc.problemdetails.enabled=true` — this auto-configures a `ResponseEntityExceptionHandler` at order 0. Module-local advice must be ordered higher to take precedence.
- Domain exceptions carry domain facts, not HTTP status codes or Spring annotations. Set a module-specific `type` URI when translating to ProblemDetail (Spring defaults to `about:blank`).
- Use `ErrorResponse.Interceptor` (via `WebMvcConfigurer`) for cross-cutting enrichment (trace IDs, correlation IDs).

| Scenario | Status | Notes |
|---|---|---|
| Validation failure (binding, type, Bean Validation) | `400` | Before domain parsing |
| Missing, malformed, expired credentials | `401` | Preserve `WWW-Authenticate: Bearer ...` |
| Authenticated but lacks required role/scope | `403` | |
| Missing resource | `404` | Module-specific problem type |
| Business rule violation, duplicate, state conflict | `409` | Not `400` or `422` — conflict without failed precondition |
| Failed precondition (`If-Match`, `If-Unmodified-Since`) | `412` | Concurrency guard |
| Semantically invalid after parsing | `422` | Well-formed but unprocessable — not `400` |
| Required precondition missing | `428` | Client must resend with `If-Match` |
| Rate limited | `429` | Include `Retry-After` |
| Unexpected failure | `500` | Log server-side, generic client message |

```java
@RestControllerAdvice(assignableTypes = NoteController.class)
@Order(Ordered.HIGHEST_PRECEDENCE)
class NoteExceptionHandler {

  @ExceptionHandler(NoteNotFoundException.class)
  ProblemDetail handleNoteNotFound(NoteNotFoundException ex) {
    var problem = ProblemDetail.forStatusAndDetail(
        HttpStatus.NOT_FOUND, "Note with ID " + ex.getNoteId() + " not found");
    problem.setTitle("Note Not Found");
    return problem;
  }
}
```

Validation errors should expose an `errors` extension array. Translate Bean Validation's `propertyPath` to a JSON Pointer `/`-prefixed path:

```json
{
  "type": "https://api.example.com/problems/validation-error",
  "title": "Validation Failed",
  "status": 400,
  "errors": [
    { "pointer": "/title", "detail": "must not be blank" },
    { "pointer": "/body", "detail": "size must be between 1 and 10000" }
  ]
}
```

## OpenAPI annotations (mandatory)

- Every controller: `@Tag`. Every operation: `@Operation(...)`. Uniqueness of `operationId` is verified by `scripts/harness/check-openapi-drift` when the generated `docs/generated/openapi.json` is refreshed — the JVM-level drift check is the authoritative gate.
- Every operation must document the successful response plus known `4xx`/`5xx` responses.
- Every request and response DTO must have `@Schema`. Add examples for non-trivial payloads.
- Document per-operation security explicitly. Public endpoints must be explicit, not implicit.
- Document pagination, filtering, ordering, and semantically important headers (`Location`, `ETag`, `WWW-Authenticate`, `Retry-After`, `RateLimit`, `RateLimit-Policy`, `Link`, `Deprecation`, `Sunset`, `Idempotency-Key`).
- Keep `docs/generated/openapi.json` in sync — validated by `scripts/harness/check-openapi-drift`.
- Use springdoc-openapi v3.x for Spring Boot 4 (v2.x is for Boot 3).

Nudge: scripts/harness/lib/hook-checks.sh::check_openapi_annotations_present — PostToolUse hook flags any src/main/java/**/rest/*Controller.java that declares @RestController without a @Tag, or a @<Verb>Mapping method without a preceding @Operation annotation. Nothing more — operationId uniqueness and tag-list completeness belong to the JVM drift check.

## Accepted when

- CSRF is disabled globally because this project is a stateless JWT API with no cookie-based session contract.
- Missing `@Valid` on `@RequestBody` is acceptable only when the body truly has no Bean Validation rules and that choice is intentional.
- The reference module `notepad` may simplify mapping, response construction, and OpenAPI annotations for trivial examples (e.g., omitting `operationId`, `Location` header, explicit `consumes`/`produces`). New real modules should follow the full guidance above.
