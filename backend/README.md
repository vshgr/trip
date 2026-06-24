# Trip Backend

Backend для iOS-приложения Trip. Он добавлен в существующий iOS-репозиторий как Go-сервис, не меняя Xcode-проект.

## Как запустить

Самый простой способ локального запуска:

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
docker compose up --build
```

После запуска доступны:

- API: `http://localhost:8080`
- Swagger UI: `http://localhost:8081`
- PostgreSQL: `localhost:5432`

Остановить:

```bash
docker compose down
```

Остановить и удалить локальные данные PostgreSQL:

```bash
docker compose down --volumes
```

## Swagger

Swagger UI запускается вместе с Docker Compose:

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
docker compose up --build
```

Открой в браузере:

```text
http://localhost:8081
```

Контракт лежит здесь:

```text
backend/api/openapi.yaml
```

Swagger содержит русские описания методов, request/response-схемы, enum-значения и назначение каждого endpoint.

## База данных

Локальный PostgreSQL запускается в Docker.

Данные для DBeaver:

- Host: `localhost`
- Port: `5432`
- Database: `trip`
- Username: `trip`
- Password: `trip`
- JDBC URL: `jdbc:postgresql://localhost:5432/trip`

Миграции находятся в `backend/db/migrations`. Примененные версии хранятся в таблице `schema_migrations`.

Seed-миграция `000002_seed_europe_trip` создает демо-поездку:

```text
7a835df2-a238-4c4b-9f36-5da11a42b40e
```

## Архитектура

Выбран Go modular monolith:

- один backend-процесс проще запускать, деплоить и отлаживать на ранней стадии продукта;
- домены поездок, маршрута, расходов, пользователей и виджета тесно связаны;
- микросервисы сейчас добавили бы сетевую сложность, распределенные транзакции и лишнюю DevOps-нагрузку;
- внутренние границы модулей сохраняются, поэтому при росте продукта части можно будет выделить позже.

Текущие слои:

- `cmd/api`: запуск HTTP API;
- `cmd/migrate`: запуск SQL-миграций;
- `internal/platform`: конфиг, база, HTTP helpers, middleware, logging;
- `internal/itinerary/domain`: доменная логика расписания;
- `internal/expenses/domain`: доменная логика денег и валют;
- `db/migrations`: структура PostgreSQL и seed-данные;
- `api/openapi.yaml`: публичный контракт для iOS.

## Soft delete

Удаление поездки реализовано мягко:

```http
DELETE /api/v1/trips/{trip_id}
```

Запись не удаляется из PostgreSQL физически. Backend выставляет `deleted_at`, обновляет `updated_at` и увеличивает `version`. Это нужно, чтобы позже добавить восстановление поездки и не терять пользовательские данные.

Такой же подход используется для plan items и expenses.

## Роли и права

Есть два уровня ролей.

Системная роль пользователя:

- `admin`: администрирование системы, будущая модерация/поддержка;
- `user`: обычный пользователь приложения.

Роль внутри конкретной поездки:

- `owner`: владелец поездки;
- `editor`: может редактировать маршрут и расходы;
- `viewer`: только просмотр.

Почему роли разделены: `admin/user` отвечает за права в системе целиком, а `owner/editor/viewer` отвечает за доступ к конкретной поездке. Один и тот же пользователь может быть обычным `user`, но `owner` в одной поездке и `viewer` в другой.

## Яндекс ID

Backend уже содержит endpoint:

```http
POST /api/v1/auth/yandex
```

iOS получает OAuth token через Yandex LoginSDK и отправляет его backend. Backend проверяет токен через Яндекс, создает или находит пользователя, связывает аккаунт и выдает backend `access_token`/`refresh_token`.

Подробный план: `docs/backend/yandex-id.md`.

## Документация

- `docs/backend/swagger.md`: как запустить и использовать Swagger.
- `docs/backend/local-checks.md`: ручная проверка backend.
- `docs/backend/architecture.md`: архитектура и обоснование.
- `docs/backend/domain-model.md`: доменная модель.
- `docs/backend/roles-and-permissions.md`: роли и права.
- `docs/backend/yandex-id.md`: план подключения Яндекс ID.
- `docs/backend/migration-plan.md`: миграция iOS с UserDefaults.

## Vendor

`vendor/` закоммичен специально. У локального Docker сейчас есть TLS-проблема при обращении к `proxy.golang.org`, поэтому сборка без `vendor/` может падать.

Для виртуального сервера это не проблема: `vendor/` делает сборку более воспроизводимой и менее зависимой от внешней сети. Минус только в размере репозитория. Когда CI/CD или сервер будут нормально ходить в Go proxy с корректными сертификатами, можно будет убрать `vendor/` и вернуть обычную загрузку модулей.

## Проверка

Тесты:

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
make test
```

Быстрая проверка API:

```bash
curl http://localhost:8080/health/ready
curl http://localhost:8080/api/v1/trips
```

Подробные команды проверки: `docs/backend/local-checks.md`.
