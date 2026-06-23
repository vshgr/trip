# API Decisions

- Base path is `/api/v1`.
- JSON fields use `snake_case`.
- Success responses are wrapped in `{ "data": ... }`.
- List responses include `{ "meta": { "next_cursor": null } }` when paginated.
- Error responses are wrapped in `{ "error": ... }`.
- Dates use `YYYY-MM-DD`.
- Datetimes use RFC3339.
- IDs are UUID strings.
- Generated API DTOs must be mapped to domain models and not passed directly to SwiftUI views.
