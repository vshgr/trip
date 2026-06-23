# UserDefaults Migration Plan

## Current Local Storage

- `trip.catalog.v1`
- `trip.days.editable.v5.<trip_uuid>`
- `trip.days.editable.v4`
- `trip.expenses.v2`
- `trip.expense.rates.v1`
- `trip.expense.rates.date.v1`
- App Group `trip.days.shared.europe`

## Import

`POST /api/v1/import/local-data` imports trips, cities, guest parties, days, plan items, expenses, and shares in one transaction.

## Local IDs

- Keep local trip/item/expense UUIDs as `client_id`.
- Store `TripDay.id: Int` as import metadata or resolve by `dateKey`.
- Return server UUID mappings to the client.

## Guest Participants

Local participants are strings. Import them as `trip_parties`, not fake users.

The current default trip seeds `Алиса`, `Яна`, `Уля`, and `Маша` as guest parties. Demo expenses should be treated as local data unless the client marks them differently in a future migration flag.

## Rollback

If import fails, the server transaction rolls back and the iOS app keeps using local UserDefaults unchanged.

## Phases

1. Backend runs separately; iOS remains local-first.
2. Login enables import of local data.
3. Server becomes source of truth; UserDefaults is cache.
4. Stores move behind repository protocols.
