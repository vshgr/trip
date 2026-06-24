# Swagger и документация API

## Как запустить Swagger

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
docker compose up --build
```

Открыть:

```text
http://localhost:8081
```

Swagger UI читает файл:

```text
backend/api/openapi.yaml
```

## Что есть в Swagger

- список всех endpoint;
- русское описание назначения каждого метода;
- параметры path;
- request body;
- response body;
- enum-значения;
- error envelope;
- bearer auth схема.

Подробное человекочитаемое описание каждого endpoint, всех полей и примеров лежит в `docs/backend/api-reference.md`.

## Как использовать для iOS

1. Открыть `http://localhost:8081`.
2. Найти нужный endpoint.
3. Посмотреть `Request body`.
4. Посмотреть `Responses`.
5. Создать Swift DTO под схему.
6. Не использовать DTO напрямую во View, а маппить в доменную модель.

## Главные endpoint для первой iOS-интеграции

- `GET /api/v1/trips`
- `GET /api/v1/trips/{trip_id}`
- `GET /api/v1/trips/{trip_id}/days`
- `GET /api/v1/trips/{trip_id}/plan-items`
- `GET /api/v1/trips/{trip_id}/expenses`
- `GET /api/v1/trips/{trip_id}/balances`
- `GET /api/v1/trips/{trip_id}/widget`

После read-интеграции можно подключать:

- `POST /api/v1/trips`
- `PATCH /api/v1/trips/{trip_id}`
- `DELETE /api/v1/trips/{trip_id}`
- create/update/delete для plan items и expenses.

## Soft delete в Swagger

Методы удаления описаны как мягкое удаление. Они не удаляют строки из базы, а выставляют `deleted_at`.
