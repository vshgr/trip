# Статус Backend API

## Реализовано

- Health: `GET /health/live`, `GET /health/ready`.
- Auth: local register/login/refresh/logout, `GET/PATCH /api/v1/me`, вход через `POST /api/v1/auth/yandex`.
- Trips: список, создание, чтение, обновление, мягкое удаление.
- Itinerary: дни маршрута, список/создание/обновление/мягкое удаление plan items, расчет заполненности расписания.
- Expenses: список/создание/обновление/мягкое удаление расходов, доли участников, балансы, упрощенные переводы.
- Widget: агрегированная read model для iOS WidgetKit.
- Import: базовый импорт локальных поездок.

## Seed-данные

Миграция `backend/db/migrations/000002_seed_europe_trip.up.sql` создает демо-поездку:

```text
7a835df2-a238-4c4b-9f36-5da11a42b40e
```

В seed входят города, 19 дней маршрута, plan items, 4 гостевых участника и демо-расходы в EUR/RUB.

## Инфраструктура

- PostgreSQL запускается через Docker Compose.
- Миграции применяет `cmd/migrate`.
- OpenAPI-контракт находится в `backend/api/openapi.yaml`.
- Swagger UI запускается на `http://localhost:8081`.
- Связки Яндекс ID хранятся в `user_identity_providers`.
- Системная роль пользователя хранится в `users.role`.

## Следующие продуктовые шаги

- Подключить iOS к Swagger/OpenAPI DTO.
- Добавить Yandex LoginSDK в iOS и отправлять OAuth token на backend.
- Включить обязательную авторизацию для write endpoints.
- Добавить проверку membership-прав для каждой поездки.
- Добавить восстановление мягко удаленной поездки.
- Позже добавить приглашения, роли участников поездки в UI, receipts/OCR и статистику расходов.
