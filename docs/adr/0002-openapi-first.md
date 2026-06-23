# ADR 0002: OpenAPI First

## Status

Accepted

## Decision

Maintain `backend/api/openapi.yaml` as the API contract before wiring generated transport types.

## Consequences

- iOS and backend can agree on DTOs before implementation details.
- Generated server and Swift client code can be introduced without replacing domain models.
