# Local Backend Checks

## Start

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
docker compose up --build
```

API: `http://localhost:8080`

PostgreSQL for DBeaver:

- Host: `localhost`
- Port: `5432`
- Database: `trip`
- User: `trip`
- Password: `trip`

## Health

```bash
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

## Seed Trip

Demo trip id:

```text
7a835df2-a238-4c4b-9f36-5da11a42b40e
```

```bash
curl http://localhost:8080/api/v1/trips
curl http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e
curl http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/days
curl http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/plan-items
curl http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/expenses
curl http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/balances
curl http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/widget
```

## Auth

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo-local@example.com","display_name":"Demo Local","password":"password123"}'
```

Use the returned `access_token`:

```bash
curl http://localhost:8080/api/v1/me \
  -H 'Authorization: Bearer <access_token>'
```

## Create Trip

```bash
curl -X POST http://localhost:8080/api/v1/trips \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Local Test Trip",
    "start_date": "2026-08-01",
    "end_date": "2026-08-03",
    "timezone": "Europe/Moscow",
    "cities": ["Москва"],
    "parties": ["Алиса", "Яна"]
  }'
```

Then use the returned `data.id` for `GET`, `PATCH`, and `DELETE`.

## Stop

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
docker compose down
```

To remove all local database data and start from migrations again:

```bash
docker compose down --volumes
docker compose up --build
```
