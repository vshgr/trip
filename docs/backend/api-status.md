# Backend API Status

## Implemented

- `GET /health/live`
- `GET /health/ready`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/yandex`
- `GET /api/v1/me`
- `PATCH /api/v1/me`
- `GET /api/v1/trips`
- `POST /api/v1/trips`
- `GET /api/v1/trips/{trip_id}`
- `PATCH /api/v1/trips/{trip_id}`
- `DELETE /api/v1/trips/{trip_id}`
- `GET /api/v1/trips/{trip_id}/days`
- `GET /api/v1/trips/{trip_id}/plan-items`
- `POST /api/v1/trips/{trip_id}/plan-items`
- `PATCH /api/v1/trips/{trip_id}/plan-items/{item_id}`
- `DELETE /api/v1/trips/{trip_id}/plan-items/{item_id}`
- `GET /api/v1/trips/{trip_id}/schedule-progress`
- `GET /api/v1/trips/{trip_id}/expenses`
- `POST /api/v1/trips/{trip_id}/expenses`
- `PATCH /api/v1/trips/{trip_id}/expenses/{expense_id}`
- `DELETE /api/v1/trips/{trip_id}/expenses/{expense_id}`
- `GET /api/v1/trips/{trip_id}/balances`
- `GET /api/v1/trips/{trip_id}/widget`
- `POST /api/v1/import/local-data`

`/health/ready` uses a real PostgreSQL connection through `pgxpool`.

Trip, itinerary, expense, balance, widget, auth, and import endpoints use real PostgreSQL data.

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
- Yandex ID account links through `user_identity_providers`.

## Contracted But Not Implemented Yet

The routes below are not part of the current OpenAPI contract yet, but are likely next product needs:

- Trip invitations and member roles.
- Receipt upload and receipt item assignment.
- Expense summaries by category/date.
- Hard authorization checks for every trip membership.

## Next Implementation Step

Connect the iOS app to Yandex LoginSDK and pass the Yandex OAuth token to `POST /api/v1/auth/yandex`.
