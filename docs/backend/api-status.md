# Backend API Status

## Implemented

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

`/health/ready` uses a real PostgreSQL connection through `pgxpool`.

Trip, itinerary, expense, balance, and widget endpoints are currently read-only and use real PostgreSQL data.

## Seed Data

The migration `backend/db/migrations/000002_seed_europe_trip.up.sql` creates local demo data:

- demo trip: `7a835df2-a238-4c4b-9f36-5da11a42b40e`;
- cities: Barcelona, Ibiza, Nice, Paris, Brussels, Amsterdam;
- 19 trip days from `2026-07-03` to `2026-07-21`;
- initial itinerary plan items;
- four trip parties and sample expenses in EUR and RUB.

## Infrastructure Ready

- PostgreSQL schema migration runner: `cmd/migrate`.
- Docker Compose services: `postgres`, `migrate`, `api`.
- Initial schema for identity, trips, itinerary, expenses, widgets read model inputs, and receipts.

## Contracted But Not Implemented Yet

The routes below are listed in `backend/api/openapi.yaml`, but handlers are not implemented yet:

- Auth: register, login, refresh, logout, me.
- Trips: create, update, delete.
- Itinerary: create/update/delete plan items, reorder.
- Expenses: create/update/delete expenses, summaries.
- Local data import.

## Next Implementation Step

Identity should be implemented next because write APIs need authenticated users and trip membership policy checks.
