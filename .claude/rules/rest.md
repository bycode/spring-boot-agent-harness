---
paths:
  - "src/**/rest/**"
---

# REST adapter rules

Inbound adapter. Receives HTTP requests, parses into domain shapes, delegates to use cases, maps results to responses.

## Controller pattern

Thin controllers: parse, delegate, map. No business logic.

```java
@PostMapping
ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest request) {
    var order = createOrderUseCase.execute(request.toDomain());
    return ResponseEntity.status(HttpStatus.CREATED).body(OrderResponse.from(order));
}
```

## DTO mapping

Static factory methods on records. Direction: parse toward domain inbound, map away from domain outbound.

- Request DTO: `request.toDomain()` converts to domain/command type. Parsing and validation happen here.
- Response DTO: `ResponseRecord.from(domainResult)` converts from domain type.
- Domain types never have `toResponse()` or `toDto()` methods. Only adapter types have mapping methods.
- No mapping frameworks.

## Error handling -- RFC 9457 Problem Details

Single `@RestControllerAdvice` translates domain exceptions to HTTP responses using `ProblemDetail`.

| Pattern | HTTP status |
|---|---|
| Entity not found | 404 (use `Optional` return + controller check) |
| Business rule violation | 409 Conflict |
| Invalid input (after parsing) | 422 Unprocessable Entity |
| Validation failure (before parsing) | 400 Bad Request |
| Authorization failure | 403 Forbidden |
| Unexpected / infrastructure | 500 (log full trace, return generic message) |

Enable globally: `spring.mvc.problemdetails.enabled=true`

Rules:
- Domain exceptions carry domain context (IDs, names), not HTTP codes.
- Catch-all `@ExceptionHandler(Exception.class)` for 500s: never expose internals.
- No HTTP status codes or error codes in domain exceptions.
- No catching exceptions in use cases to wrap them.

**Accepted when:**
- CSRF disabled globally → stateless JWT API with no cookie-based sessions (this project's security posture).
- Missing `@Valid` on `@RequestBody` → endpoint intentionally accepts unvalidated payload (must be documented in comment).
- Controller returns domain type directly → reference module `notepad` may simplify mapping for trivial cases; real modules must use DTOs.

## OpenAPI annotations (mandatory)

Every controller must have `@Tag`. Every endpoint must have `@Operation` and `@ApiResponse`. Every request/response DTO must have `@Schema`. When adding, modifying, or removing endpoints, update these annotations to keep the generated spec in sync with the code. The committed spec at `docs/generated/openapi.json` is validated by `scripts/harness/check-openapi-drift` — stale specs fail `full-check`.

Note: OpenAPI catches **spec drift** (committed spec doesn't match running code). It does not replace the module contract's consumer surface, which still needs to be reviewed and updated alongside endpoint changes. OpenAPI is a supplementary machine-readable mirror, not the contract system.

## Parse, don't validate

All raw HTTP input is converted to domain shapes at this boundary. Use Bean Validation (`@Valid`) on DTOs for structural validation, then `toDomain()` for semantic parsing. The use case receives well-typed domain objects, never raw request data.
