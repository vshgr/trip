# Локальная проверка Backend

## Запуск

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
docker compose up --build
```

Адреса:

- API: `http://localhost:8080`
- Swagger UI: `http://localhost:8081`
- PostgreSQL: `localhost:5432`

## DBeaver

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

## Swagger

Открой:

```text
http://localhost:8081
```

Swagger читает файл:

```text
backend/api/openapi.yaml
```

## Seed-поездка

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

## Создание пользователя

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo-local@example.com","display_name":"Demo Local","password":"password123"}'
```

В ответе будет `access_token`. Его можно использовать так:

```bash
curl http://localhost:8080/api/v1/me \
  -H 'Authorization: Bearer <access_token>'
```

## Создание поездки

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

## Мягкое удаление поездки

```bash
curl -X DELETE http://localhost:8080/api/v1/trips/<trip_id>
```

Запись останется в базе, но у нее появится `deleted_at`.

## Остановка

```bash
docker compose down
```

Полная очистка локальной базы:

```bash
docker compose down --volumes
docker compose up --build
```
