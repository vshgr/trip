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

Migrations are plain SQL files under `db/migrations`. Applied versions are recorded in `schema_migrations`.

Useful commands:

```bash
cd backend
docker compose up -d postgres
make migrate
make run
docker compose down
```

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

Implemented in Stage 1:

- `GET /health/live`
- `GET /health/ready`

Planned API resources are defined in `api/openapi.yaml`; auth, trips, itinerary, expenses, widget, and import endpoints are not implemented yet.

See `../docs/backend/api-status.md` for the current implementation status.

## Troubleshooting

- If `/health/ready` returns 503, check `DATABASE_URL`.
- If local `go` is missing, install Go from `go.dev/dl` or add `/usr/local/go/bin` to `PATH`.
