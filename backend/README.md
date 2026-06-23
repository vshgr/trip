# Trip Backend

Go backend for the Trip iOS app. The backend is being added as a modular monolith in the existing iOS repository without changing the Xcode project.

## Architecture

- HTTP transport: `net/http` for Stage 1.
- Application modules: identity, trips, itinerary, expenses, widgets, receipts.
- Domain logic lives under each module's `domain` package.
- Persistence will use PostgreSQL migrations and sqlc-generated query code in later stages.
- API responses use `{ "data": ... }` and `{ "error": ... }` envelopes.

Stage 1 intentionally keeps runtime dependencies minimal because this local workspace has no Go toolchain installed. The CI/Docker image uses Go and will be the source of truth for compilation until a local Go installation is available.

## Run

```bash
cd backend
docker compose up --build
```

API:

- `GET http://localhost:8080/health/live`
- `GET http://localhost:8080/health/ready`

## Environment

Copy `.env.example` and override values for local or production environments.

Important variables:

- `HTTP_PORT`
- `HTTP_READ_TIMEOUT`
- `HTTP_WRITE_TIMEOUT`
- `HTTP_IDLE_TIMEOUT`
- `HTTP_SHUTDOWN_TIMEOUT`
- `DATABASE_URL`
- `JWT_SECRET`
- `LOG_LEVEL`

## Migrations

Migration files live in `db/migrations`.

Stage 1 defines the initial schema. A migration runner will be wired in the next persistence stage; until then, run the SQL with your preferred migration tool.

## Tests

```bash
cd backend
go test ./...
```

Current unit tests cover:

- health router behavior;
- schedule occupancy interval union/clipping;
- integer equal-split remainder distribution.

## Endpoints

Implemented in Stage 1:

- `GET /health/live`
- `GET /health/ready`

Planned API resources are defined in `api/openapi.yaml`.

## Troubleshooting

- If `/health/ready` returns 503, check `DATABASE_URL`.
- If local `go` is missing, install Go 1.23+ or run through Docker/CI.
