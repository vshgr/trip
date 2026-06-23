# Backend API Status

## Implemented

- `GET /health/live`
- `GET /health/ready`

`/health/ready` uses a real PostgreSQL connection through `pgxpool`.

## Infrastructure Ready

- PostgreSQL schema migration runner: `cmd/migrate`.
- Docker Compose services: `postgres`, `migrate`, `api`.
- Initial schema for identity, trips, itinerary, expenses, widgets read model inputs, and receipts.

## Contracted But Not Implemented Yet

The routes below are listed in `backend/api/openapi.yaml`, but handlers are not implemented yet:

- Auth: register, login, refresh, logout, me.
- Trips: list, create, read, update, delete.
- Itinerary: days, plan items, reorder, schedule progress.
- Expenses: expenses, balances, summaries.
- Widget read model.
- Local data import.

## Next Implementation Step

Identity should be implemented first because all trip and expense APIs need an authenticated user and trip membership policy checks.
