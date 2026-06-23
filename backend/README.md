# Trip Backend

Go backend for the Trip iOS app. The backend is being added as a modular monolith in the existing iOS repository without changing the Xcode project.

## Architecture

- HTTP transport: `net/http` for Stage 1.
- Application modules: identity, trips, itinerary, expenses, widgets, receipts.
- Domain logic lives under each module's `domain` package.
- Persistence will use PostgreSQL migrations and sqlc-generated query code in later stages.
- API responses use `{ "data": ... }` and `{ "error": ... }` envelopes.

Stage 1 intentionally keeps runtime dependencies minimal. Use the system Go toolchain installed from `go.dev`.

## Local Go Setup

Install Go for macOS Apple Silicon from `https://go.dev/dl/`, then check:

```bash
go version
```

If `go` is installed but not found, add it to your zsh path:

```bash
echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
go version
```

## Run

The API now requires PostgreSQL. The easiest local path is Docker Compose:

```bash
cd backend
docker compose up --build
```

API:

- `GET http://localhost:8080/health/live`
- `GET http://localhost:8080/health/ready`
- `GET http://localhost:8080/api/v1/trips`
- `GET http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e`
- `GET http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/days`
- `GET http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/plan-items`
- `GET http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/schedule-progress`
- `GET http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/expenses`
- `GET http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/balances`
- `GET http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/widget`

Docker Compose starts:

- `postgres` on `localhost:5432`;
- `migrate`, which applies `db/migrations/*.up.sql`;
- `api` on `localhost:8080`.

If you already have PostgreSQL running locally:

```bash
cd backend
make migrate
make run
```

You can also run from the repository root:

```bash
scripts/backend-run-local.sh
```

## Database

Local Docker credentials:

- database: `trip`
- user: `trip`
- password: `trip`
- URL: `postgres://trip:trip@localhost:5432/trip?sslmode=disable`
- JDBC URL for DBeaver: `jdbc:postgresql://localhost:5432/trip`

Migrations are plain SQL files under `db/migrations`. Applied versions are recorded in `schema_migrations`.

The seed migration `000002_seed_europe_trip` creates a demo trip, route days, plan items, trip parties, expenses, and expense shares. This data is intended for local API and iOS integration checks.

Useful commands:

```bash
cd backend
docker compose up -d postgres
make migrate
make run
docker compose down
```

To inspect data in DBeaver, start Docker Compose first, then create a PostgreSQL connection with:

- Host: `localhost`
- Port: `5432`
- Database: `trip`
- Username: `trip`
- Password: `trip`

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

The initial schema creates users, sessions, trips, cities, members, guest parties, days, plan items, expenses, shares, receipts, and receipt items.

## Tests

```bash
cd backend
make test
```

Current unit tests cover:

- health router behavior;
- schedule occupancy interval union/clipping;
- integer equal-split remainder distribution.
- supported currencies matching the current iOS app: RUB, EUR, USD, KZT, JPY.

## Endpoints

Implemented:

- `GET /health/live`
- `GET /health/ready`
- `GET /api/v1/trips`
- `GET /api/v1/trips/{trip_id}`
- `GET /api/v1/trips/{trip_id}/days`
- `GET /api/v1/trips/{trip_id}/plan-items`
- `GET /api/v1/trips/{trip_id}/schedule-progress`
- `GET /api/v1/trips/{trip_id}/expenses`
- `GET /api/v1/trips/{trip_id}/balances`
- `GET /api/v1/trips/{trip_id}/widget`

Planned API resources are defined in `api/openapi.yaml`; auth, write operations, and local data import endpoints are not implemented yet.

See `../docs/backend/api-status.md` for the current implementation status.

## Vendor

`vendor/` is committed so Docker builds can run without downloading Go modules from `proxy.golang.org`. This helps in networks or Docker environments with TLS/proxy issues. If Docker can access `proxy.golang.org` normally, the project can be switched back to online module downloads by removing `vendor/` and dropping `-mod=vendor` from the Docker build.

## Troubleshooting

- If `/health/ready` returns 503, check `DATABASE_URL`.
- If local `go` is missing, install Go from `go.dev/dl` or add `/usr/local/go/bin` to `PATH`.
