# Подробная документация Backend API

Эта документация дополняет Swagger `backend/api/openapi.yaml` и объясняет назначение каждого endpoint, поля запросов, поля ответов и примеры. Все успешные ответы backend заворачивает в `data`, ошибки - в `error`.

Базовый адрес локально:

```text
http://localhost:8080
```

Swagger UI:

```text
http://localhost:8081
```

## Общие правила

- `id`, `trip_id`, `item_id`, `expense_id`, `party_id`, `day_id` - UUID-строки.
- Даты поездки и дней передаются как `YYYY-MM-DD`.
- Даты-время передаются в RFC3339, например `2026-07-04T20:30:00+02:00`.
- Деньги передаются в minor units: `1000 RUB` означает 10 рублей 00 копеек.
- `deleted_at` используется для мягкого удаления. Удаленные поездки, расходы и plan items не попадают в обычные списки.
- `version` увеличивается при изменении сущности и нужен для будущей optimistic concurrency.

## Error response

Любая ошибка приходит в одном формате:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request body",
    "request_id": "req_...",
    "details": [
      {
        "field": "title",
        "reason": "required"
      }
    ]
  }
}
```

Поля:

- `code`: машинно-читаемый код ошибки.
- `message`: человекочитаемое описание.
- `request_id`: идентификатор запроса для логов.
- `details`: опциональный массив ошибок по конкретным полям.

## Health

### GET `/health/live`

Проверяет, что API-процесс живой. PostgreSQL не проверяется.

Пример ответа:

```json
{
  "data": {
    "status": "ok"
  }
}
```

Поля:

- `data.status`: `ok`, если процесс отвечает.

### GET `/health/ready`

Проверяет, что API может подключиться к PostgreSQL.

Пример ответа:

```json
{
  "data": {
    "status": "ready"
  }
}
```

Поля:

- `data.status`: `ready`, если база доступна.

## Auth

### POST `/api/v1/auth/register`

Локальная регистрация пользователя для разработки. В production основным входом должен быть Яндекс ID.

Request:

```json
{
  "email": "demo@example.com",
  "display_name": "Алиса",
  "password": "password123",
  "device_id": "ios-device-id",
  "device_name": "iPhone 15"
}
```

Поля запроса:

- `email`: email пользователя, обязательный.
- `display_name`: отображаемое имя, обязательное.
- `password`: пароль минимум 8 символов, обязательный.
- `device_id`: опциональный идентификатор устройства.
- `device_name`: опциональное имя устройства.

Response `201`:

```json
{
  "data": {
    "access_token": "jwt...",
    "refresh_token": "opaque...",
    "token_type": "Bearer",
    "expires_at": "2026-06-25T12:15:00Z",
    "user": {
      "id": "11111111-1111-1111-1111-111111111111",
      "email": "demo@example.com",
      "display_name": "Алиса",
      "role": "user",
      "avatar_url": null
    }
  }
}
```

Поля ответа:

- `access_token`: короткоживущий JWT для `Authorization: Bearer`.
- `refresh_token`: долгоживущий opaque token для обновления сессии.
- `token_type`: всегда `Bearer`.
- `expires_at`: срок жизни access token.
- `user.id`: UUID пользователя в backend.
- `user.email`: email пользователя.
- `user.display_name`: имя для UI.
- `user.role`: системная роль `admin` или `user`.
- `user.avatar_url`: ссылка на аватар или `null`.

### POST `/api/v1/auth/login`

Вход локального пользователя по email/password.

Request:

```json
{
  "email": "demo@example.com",
  "password": "password123",
  "device_id": "ios-device-id",
  "device_name": "iPhone 15"
}
```

Поля такие же, как в register, кроме `display_name`.

Response `200`: такой же, как у register.

### POST `/api/v1/auth/yandex`

Основной endpoint для входа через Яндекс ID. iOS получает OAuth token через Yandex LoginSDK и отправляет его backend. Backend сам запрашивает профиль у Яндекса, создает или находит пользователя и возвращает backend-сессию.

Request:

```json
{
  "oauth_token": "token-from-yandex-login-sdk",
  "device_id": "ios-device-id",
  "device_name": "iPhone 15"
}
```

Поля запроса:

- `oauth_token`: OAuth token от Yandex LoginSDK, обязательный.
- `device_id`: опционально.
- `device_name`: опционально.

Response `200`: такой же `AuthResponse`, как у register/login.

Важно для iOS: сырой `oauth_token` Яндекса не нужно хранить. После ответа backend хранить надо только backend `access_token` и `refresh_token`.

### POST `/api/v1/auth/refresh`

Обновляет backend-сессию. Старый refresh token отзывается, backend выдает новую пару токенов.

Request:

```json
{
  "refresh_token": "opaque..."
}
```

Поля:

- `refresh_token`: refresh token, полученный при login/register/yandex.

Response `200`: новый `AuthResponse`.

### POST `/api/v1/auth/logout`

Отзывает refresh token.

Request:

```json
{
  "refresh_token": "opaque..."
}
```

Response:

```json
{
  "data": {
    "status": "ok"
  }
}
```

### GET `/api/v1/me`

Возвращает текущего пользователя. Требует header:

```text
Authorization: Bearer <access_token>
```

Response:

```json
{
  "data": {
    "id": "11111111-1111-1111-1111-111111111111",
    "email": "demo@example.com",
    "display_name": "Алиса",
    "role": "user",
    "avatar_url": null
  }
}
```

### PATCH `/api/v1/me`

Обновляет имя текущего пользователя.

Request:

```json
{
  "display_name": "Алиса Т."
}
```

Поля:

- `display_name`: новое отображаемое имя, обязательное.

Response: `UserEnvelope`, как у `/me`.

## Trips

### GET `/api/v1/trips`

Возвращает список активных поездок. Мягко удаленные поездки не возвращаются.

Response:

```json
{
  "data": [
    {
      "id": "7a835df2-a238-4c4b-9f36-5da11a42b40e",
      "title": "Europe Trip",
      "start_date": "2026-07-03",
      "end_date": "2026-07-21",
      "cities": [
        {
          "id": "20000000-0000-0000-0000-000000000001",
          "name": "Барселона",
          "sort_order": 0
        }
      ],
      "member_count": 4,
      "schedule_occupancy_percent": 2,
      "expense_totals_by_currency": {
        "EUR": 96600,
        "RUB": 720000
      },
      "approximate_total_rub": null,
      "nearest_activity": {
        "id": "50000000-0000-0000-0000-000000000001",
        "source_day_id": "40000000-0000-0000-0000-000000000001",
        "title": "Перелет в Барселону",
        "start_at": "2026-07-03T15:00:00Z",
        "period": null
      },
      "updated_at": "2026-06-25T00:00:00Z",
      "version": 1
    }
  ],
  "meta": {
    "next_cursor": null
  }
}
```

Поля поездки в списке:

- `id`: UUID поездки.
- `title`: название поездки.
- `start_date`, `end_date`: диапазон дат.
- `cities`: упорядоченный маршрут.
- `member_count`: сейчас количество гостевых участников `trip_parties`.
- `schedule_occupancy_percent`: заполненность расписания exact-time активностями.
- `expense_totals_by_currency`: суммы расходов по валютам в minor units.
- `approximate_total_rub`: будущий агрегат с курсами, сейчас может быть `null`.
- `nearest_activity`: ближайший пункт плана или `null`.
- `updated_at`: время последнего обновления.
- `version`: версия поездки.

### POST `/api/v1/trips`

Создает поездку, города, гостевых участников и дни.

Request:

```json
{
  "title": "Local Test Trip",
  "start_date": "2026-08-01",
  "end_date": "2026-08-03",
  "timezone": "Europe/Moscow",
  "cities": ["Москва", "Санкт-Петербург"],
  "parties": ["Алиса", "Яна"],
  "days": [
    {
      "local_id": "0",
      "date": "2026-08-01",
      "city": "Москва"
    }
  ]
}
```

Поля:

- `title`: название, обязательное.
- `start_date`: дата начала, обязательная.
- `end_date`: дата конца, обязательная.
- `timezone`: timezone поездки, опционально.
- `cities`: города маршрута в порядке посещения.
- `parties`: гостевые участники расходов.
- `days`: опциональный список дней. Если не передан, backend сгенерирует дни по диапазону дат.
- `days.local_id`: локальный id из iOS, например старый `TripDay.id`.
- `days.date`: дата дня.
- `days.city`: город дня.

Response `201`: `TripEnvelope`.

### GET `/api/v1/trips/{trip_id}`

Возвращает детали поездки.

Response:

```json
{
  "data": {
    "id": "7a835df2-a238-4c4b-9f36-5da11a42b40e",
    "title": "Europe Trip",
    "start_date": "2026-07-03",
    "end_date": "2026-07-21",
    "timezone": "Europe/Madrid",
    "cities": [],
    "parties": [],
    "version": 1,
    "created_at": "2026-06-25T00:00:00Z",
    "updated_at": "2026-06-25T00:00:00Z"
  }
}
```

Поля:

- `cities`: маршрут поездки.
- `parties`: гостевые участники расходов.
- остальные поля совпадают с trip summary.

### PATCH `/api/v1/trips/{trip_id}`

Частично обновляет поездку.

Request:

```json
{
  "title": "Europe Trip Updated",
  "start_date": "2026-07-03",
  "end_date": "2026-07-22",
  "timezone": "Europe/Madrid"
}
```

Все поля опциональны:

- `title`: новое название.
- `start_date`: новая дата начала.
- `end_date`: новая дата конца.
- `timezone`: timezone.

Response `200`: обновленная поездка.

### DELETE `/api/v1/trips/{trip_id}`

Мягко удаляет поездку: выставляет `deleted_at`, обновляет `updated_at`, увеличивает `version`. Строка остается в базе.

Response:

```json
{
  "data": {
    "status": "deleted"
  }
}
```

## Itinerary

### GET `/api/v1/trips/{trip_id}/days`

Возвращает дни маршрута.

Response:

```json
{
  "data": [
    {
      "id": "40000000-0000-0000-0000-000000000001",
      "local_id": "0",
      "date": "2026-07-03",
      "city": "Барселона",
      "sort_order": 0,
      "schedule_occupancy_percent": 6,
      "version": 1
    }
  ],
  "meta": {
    "next_cursor": null
  }
}
```

Поля:

- `id`: серверный UUID дня.
- `local_id`: старый локальный id iOS или `null`.
- `date`: дата.
- `city`: город дня.
- `sort_order`: порядок дня в поездке.
- `schedule_occupancy_percent`: заполненность дня.
- `version`: версия дня.

### GET `/api/v1/trips/{trip_id}/plan-items`

Возвращает элементы плана.

Response:

```json
{
  "data": [
    {
      "id": "50000000-0000-0000-0000-000000000001",
      "source_day_id": "40000000-0000-0000-0000-000000000001",
      "title": "Перелет в Барселону",
      "city": "Барселона",
      "category": "transfer",
      "schedule_type": "exact",
      "period": null,
      "start_at": "2026-07-03T15:00:00Z",
      "end_at": "2026-07-04T05:00:00Z",
      "timezone": "Europe/Madrid",
      "sort_index": 0,
      "needs_ticket": false,
      "ticket_bought": false,
      "version": 1
    }
  ],
  "meta": {
    "next_cursor": null
  }
}
```

Поля:

- `source_day_id`: UUID дня, к которому относится item.
- `title`: название активности.
- `city`: город.
- `category`: `transfer`, `rest`, `walk`, `sight`, `food`, `shopping`.
- `schedule_type`: `exact`, `period`, `unscheduled`.
- `period`: `morning`, `afternoon`, `evening`, `night` или `null`.
- `start_at`, `end_at`: exact-time интервалы или `null`.
- `timezone`: timezone exact-time активности.
- `sort_index`: порядок внутри дня.
- `needs_ticket`: нужен ли билет.
- `ticket_bought`: куплен ли билет.
- `version`: версия.

### POST `/api/v1/trips/{trip_id}/plan-items`

Создает элемент плана.

Request:

```json
{
  "source_day_id": "40000000-0000-0000-0000-000000000001",
  "title": "Casa Batllo",
  "city": "Барселона",
  "category": "sight",
  "schedule_type": "period",
  "period": "evening",
  "sort_index": 2,
  "needs_ticket": true,
  "ticket_bought": false
}
```

Для exact-time:

```json
{
  "source_day_id": "40000000-0000-0000-0000-000000000001",
  "title": "Поезд",
  "city": "Париж",
  "category": "transfer",
  "schedule_type": "exact",
  "start_at": "2026-07-13T09:00:00+02:00",
  "end_at": "2026-07-13T14:30:00+02:00",
  "timezone": "Europe/Paris",
  "sort_index": 0
}
```

Поля:

- `source_day_id`: обязательный UUID дня.
- `title`: обязательное название.
- `city_id`: опциональный UUID города из `trip_cities`.
- `city`: snapshot названия города.
- остальные поля совпадают с `PlanItem`.

### PATCH `/api/v1/trips/{trip_id}/plan-items/{item_id}`

Частично обновляет элемент плана. Все поля опциональны и совпадают с create request.

### DELETE `/api/v1/trips/{trip_id}/plan-items/{item_id}`

Мягко удаляет элемент плана через `deleted_at`.

### GET `/api/v1/trips/{trip_id}/schedule-progress`

Возвращает заполненность расписания по поездке и дням.

Response:

```json
{
  "data": {
    "trip_percent": 4,
    "days": [
      {
        "day_id": "40000000-0000-0000-0000-000000000001",
        "date": "2026-07-03",
        "occupied_minutes": 360,
        "available_minutes": 900,
        "percent": 40
      }
    ]
  }
}
```

Поля:

- `trip_percent`: общая заполненность поездки.
- `occupied_minutes`: минуты exact-time активностей.
- `available_minutes`: активное окно дня, сейчас 900 минут.
- `percent`: процент дня.

## Expenses

### GET `/api/v1/trips/{trip_id}/expenses`

Возвращает расходы и доли.

Response:

```json
{
  "data": [
    {
      "id": "60000000-0000-0000-0000-000000000001",
      "title": "Апартаменты",
      "amount_minor": 62000,
      "currency": "EUR",
      "paid_by_party_id": "30000000-0000-0000-0000-000000000001",
      "paid_by_name": "Алиса",
      "occurred_at": "2026-07-04T10:00:00Z",
      "shares": [
        {
          "id": "70000000-0000-0000-0000-000000000001",
          "party_id": "30000000-0000-0000-0000-000000000001",
          "party_name": "Алиса",
          "share_minor": 15500
        }
      ],
      "version": 1
    }
  ],
  "meta": {
    "next_cursor": null
  }
}
```

Поля:

- `amount_minor`: сумма расхода в minor units.
- `currency`: `RUB`, `EUR`, `USD`, `KZT`, `JPY`.
- `paid_by_party_id`: кто оплатил.
- `shares`: на кого и в какой сумме расход делится.

### POST `/api/v1/trips/{trip_id}/expenses`

Создает расход.

Request с ручными долями:

```json
{
  "title": "Такси",
  "amount_minor": 4800,
  "currency": "EUR",
  "paid_by_party_id": "30000000-0000-0000-0000-000000000003",
  "occurred_at": "2026-07-07T11:00:00+02:00",
  "category": "transport",
  "note": "Аэропорт",
  "shares": [
    {
      "party_id": "30000000-0000-0000-0000-000000000001",
      "share_minor": 1600
    },
    {
      "party_id": "30000000-0000-0000-0000-000000000003",
      "share_minor": 1600
    },
    {
      "party_id": "30000000-0000-0000-0000-000000000004",
      "share_minor": 1600
    }
  ]
}
```

Если `shares` не передать, backend поделит сумму поровну между всеми `trip_parties`.

### PATCH `/api/v1/trips/{trip_id}/expenses/{expense_id}`

Частично обновляет расход. Если передать `shares`, backend полностью заменит старые доли новыми. Сумма `share_minor` должна совпадать с `amount_minor`.

### DELETE `/api/v1/trips/{trip_id}/expenses/{expense_id}`

Мягко удаляет расход через `deleted_at`.

### GET `/api/v1/trips/{trip_id}/balances`

Считает балансы и упрощенные переводы по каждой валюте.

Response:

```json
{
  "data": {
    "currencies": [
      {
        "currency": "EUR",
        "members": [
          {
            "party_id": "30000000-0000-0000-0000-000000000001",
            "display_name": "Алиса",
            "balance_minor": 32800
          }
        ],
        "simplified_transfers": [
          {
            "from_party_id": "30000000-0000-0000-0000-000000000002",
            "from_name": "Яна",
            "to_party_id": "30000000-0000-0000-0000-000000000001",
            "to_name": "Алиса",
            "amount_minor": 18000
          }
        ]
      }
    ]
  }
}
```

Поля:

- `balance_minor > 0`: участнику должны.
- `balance_minor < 0`: участник должен.
- `simplified_transfers`: список переводов, который закрывает долги внутри валюты.

## Widget

### GET `/api/v1/trips/{trip_id}/widget`

Возвращает агрегированную модель для WidgetKit. iOS должен сохранить этот ответ в App Group cache, а widget продолжит читать локальные данные.

Response:

```json
{
  "data": {
    "trip_id": "7a835df2-a238-4c4b-9f36-5da11a42b40e",
    "trip_title": "Europe Trip",
    "next_city": {
      "name": "Барселона",
      "date": "2026-07-03",
      "days_until": 8
    },
    "nearest_planned_day": {
      "date": "2026-07-03"
    },
    "nearest_activity": {
      "id": "50000000-0000-0000-0000-000000000001",
      "source_day_id": "40000000-0000-0000-0000-000000000001",
      "title": "Перелет в Барселону",
      "start_at": "2026-07-03T15:00:00Z",
      "period": null
    },
    "route_progress_percent": 0,
    "generated_at": "2026-06-25T00:00:00Z"
  }
}
```

## Import

### POST `/api/v1/import/local-data`

Базовый импорт локальных поездок iOS.

Request:

```json
{
  "trips": [
    {
      "title": "Imported Trip",
      "start_date": "2026-08-01",
      "end_date": "2026-08-03",
      "timezone": "Europe/Moscow",
      "cities": ["Москва"],
      "parties": ["Алиса", "Яна"]
    }
  ]
}
```

Response:

```json
{
  "data": {
    "created_trip_ids": [
      "b9b3b4d0-0000-4000-8000-000000000000"
    ]
  }
}
```

Поля:

- `trips`: массив поездок в формате `CreateTripRequest`.
- `created_trip_ids`: UUID созданных поездок.
