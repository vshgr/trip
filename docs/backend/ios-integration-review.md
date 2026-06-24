# Анализ iOS-интеграции с Backend

Документ описывает состояние iOS после merge свежего `main`, соответствие backend endpoint экранам приложения и рекомендации по интеграции.

## Что изменилось в iOS

Проект переехал в папку:

```text
mobile/ios
```

Добавлена auth/profile зона:

- `mobile/ios/Trip/Features/Auth/AuthModels.swift`
- `mobile/ios/Trip/Features/Auth/AuthViews.swift`
- `mobile/ios/Trip/ContentView.swift`

Сейчас `AuthStore`:

- хранит профиль в `UserDefaults`;
- в debug без `YandexClientID` создает preview-профиль;
- умеет получить профиль напрямую через `GET https://login.yandex.ru/info`;
- пока не вызывает backend.

## Как лучше интегрировать Яндекс ID

Оптимальный production-flow:

1. iOS получает `oauthToken` через Yandex LoginSDK.
2. iOS вызывает `POST /api/v1/auth/yandex`.
3. Backend проверяет token через Яндекс.
4. Backend создает/находит пользователя и возвращает `access_token`, `refresh_token`, `user`.
5. iOS хранит backend-сессию, а не сырой Яндекс-токен.
6. iOS вызывает backend endpoints с `Authorization: Bearer <access_token>`.

Почему так лучше:

- бизнес-идентичность пользователя находится на backend;
- iOS не решает, существующий пользователь или новый;
- backend может централизованно связать Яндекс ID, роли и поездки;
- проще добавлять logout/refresh/session invalidation.

## Соответствие экранов и backend endpoint

### Экран входа и профиль

iOS:

- `AuthLandingView`
- `ProfileTabView`
- `AuthStore`

Backend:

- `POST /api/v1/auth/yandex`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/me`

Что нужно добавить в iOS:

- `BackendAuthAPI`.
- `TokenStore`.
- mapper из backend `User` в `AuthUserProfile`.

Рекомендуемый mapping:

- `AuthUserProfile.id` <- `user.id`
- `login` <- email до `@` или `user.id`, если email нет
- `displayName` <- `user.display_name`
- `email` <- `user.email`
- `avatarURL` <- `user.avatar_url`
- `provider` <- `.yandexID` для yandex flow
- `registeredAt`/`lastLoginAt` пока можно хранить локально или добавить в backend позже

### Каталог поездок

iOS:

- `TripsView`
- `TripCatalogStore`
- `TravelTrip`

Backend:

- `GET /api/v1/trips`
- `POST /api/v1/trips`
- `GET /api/v1/trips/{trip_id}`
- `PATCH /api/v1/trips/{trip_id}`
- `DELETE /api/v1/trips/{trip_id}`

Оценка: ручки подходят. Backend уже возвращает агрегаты для карточки: города, количество участников, заполненность плана и суммы расходов.

Важный mapping:

- `TravelTrip.id` сейчас `UUID`, backend `Trip.id` тоже UUID.
- `TravelTrip.cities: [String]` берется из `Trip.cities[].name`.
- `TravelTrip.participants: [String]` берется из `Trip.parties[].display_name`.

### План поездки

iOS:

- `PlanViews`
- `TripStore`
- `TripDay`
- `PlanItem`

Backend:

- `GET /api/v1/trips/{trip_id}/days`
- `GET /api/v1/trips/{trip_id}/plan-items`
- `POST /api/v1/trips/{trip_id}/plan-items`
- `PATCH /api/v1/trips/{trip_id}/plan-items/{item_id}`
- `DELETE /api/v1/trips/{trip_id}/plan-items/{item_id}`
- `GET /api/v1/trips/{trip_id}/schedule-progress`

Оценка: ручки нормальные и логика вынесена на backend там, где это важно:

- backend считает schedule occupancy;
- backend хранит exact timestamps;
- backend сохраняет ticket flags и порядок.

Что нужно на iOS:

- mapper `TripDayResponse + PlanItemResponse -> TripDay(items:)`;
- перевод backend period `morning/afternoon/evening/night` в русские UI-строки;
- перевод local date label `3 июля` из backend `date`.

### Расходы

iOS:

- `ExpensesView`
- `ExpenseStore`
- `ExpenseItem`

Backend:

- `GET /api/v1/trips/{trip_id}/expenses`
- `POST /api/v1/trips/{trip_id}/expenses`
- `PATCH /api/v1/trips/{trip_id}/expenses/{expense_id}`
- `DELETE /api/v1/trips/{trip_id}/expenses/{expense_id}`
- `GET /api/v1/trips/{trip_id}/balances`

Оценка: backend ручки лучше текущей локальной логики, потому что:

- деньги считаются в minor units, без `Double`;
- split shares хранятся явно;
- баланс считается на backend;
- валюты не смешиваются.

Что нужно на iOS:

- UI amount `Double/String` переводить в `amount_minor`;
- payer name заменить на `paid_by_party_id`;
- involved participant names заменить на `shares[].party_id`;
- локальный расчет split можно оставить как fallback/offline cache, но source of truth должен быть backend.

### Widget

iOS:

- `TripWidget`
- App Group `group.com.alisa.trip`

Backend:

- `GET /api/v1/trips/{trip_id}/widget`

Оценка: endpoint правильный. WidgetKit не должен напрямую ходить в сеть; iOS-приложение должно получать widget response и сохранять в App Group.

## Что в backend уже оптимально

- Карточка поездки получает агрегаты из `GET /api/v1/trips`, чтобы iOS не собирал их из нескольких запросов.
- Балансы считаются на backend.
- Расписание и пересекающиеся exact-time интервалы считаются на backend.
- Widget получает агрегированную read model.
- Soft delete снижает риск потери данных.
- OpenAPI описывает DTO для iOS.

## Что стоит добавить следующим backend-шагом

- Обязательный `Authorization` для write endpoints.
- Проверка `trip_members` для доступа к конкретной поездке.
- Endpoint восстановления поездки: например `POST /api/v1/trips/{trip_id}/restore`.
- Endpoint управления участниками поездки.
- Более полный import локальных plan items и expenses.
- Поля `registered_at` и `last_login_at` в user response, если профиль iOS должен показывать серверные даты.

## Рекомендуемый порядок iOS-интеграции

1. Добавить `APIClient` и базовый `BackendConfig`.
2. Добавить DTO по Swagger.
3. Подключить `GET /api/v1/trips`.
4. Подключить детали поездки, days, plan-items.
5. Подключить expenses и balances.
6. Подключить widget endpoint и запись App Group cache.
7. Подключить Yandex LoginSDK -> `POST /api/v1/auth/yandex`.
8. Перевести create/update/delete на backend.
9. Оставить UserDefaults как cache/offline слой.
