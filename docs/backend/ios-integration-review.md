# iOS-интеграция с Backend

Документ описывает, как подключить текущее iOS-приложение к текущим backend-ручкам, какие роли и права учитывать, какие данные хранить на клиенте и как проверять интеграцию автоматическими и ручными тестами.

## Текущее состояние проекта

iOS-проект находится в папке:

```text
mobile/ios
```

Основные файлы, которые уже затрагивают авторизацию и профиль:

- `mobile/ios/Trip/Features/Auth/AuthModels.swift`
- `mobile/ios/Trip/Features/Auth/AuthViews.swift`
- `mobile/ios/Trip/ContentView.swift`

Сейчас `AuthStore` хранит профиль в `UserDefaults`, в debug-режиме может создавать preview-профиль без backend и умеет получать профиль напрямую через `GET https://login.yandex.ru/info`. Для production это нужно заменить на схему, где Яндекс-токен используется только для первичного входа, а постоянная сессия приложения живет на backend.

## Целевая схема интеграции

1. iOS получает токен Яндекс ID через Yandex LoginSDK.
2. iOS отправляет этот токен в `POST /api/v1/auth/yandex`.
3. Backend проверяет токен у Яндекса, создает или находит пользователя.
4. Backend возвращает `access_token`, `refresh_token` и объект `user`.
5. iOS хранит backend-токены в Keychain.
6. Все запросы к Trip API идут с заголовком `Authorization: Bearer <access_token>`.
7. При `401 TOKEN_EXPIRED` iOS вызывает `POST /api/v1/auth/refresh`, обновляет токены и повторяет исходный запрос один раз.
8. При logout iOS вызывает `POST /api/v1/auth/logout`, удаляет токены из Keychain и очищает локальный cache.

Важный принцип: Яндекс ID подтверждает личность, но бизнес-аккаунт, роли, поездки и права находятся на backend.

## Рекомендуемая структура iOS-клиента

Нужно добавить отдельный сетевой слой, чтобы UI не работал напрямую с `URLSession`.

Рекомендуемые компоненты:

- `BackendConfig`: base URL, timeout, app version, debug flags.
- `APIClient`: единая обертка над `URLSession`, JSON encode/decode, обработка HTTP-ошибок.
- `AuthTokenStore`: хранение `access_token` и `refresh_token` в Keychain.
- `AuthInterceptor`: добавляет `Authorization` и умеет refresh/retry.
- `DTO`: структуры ответов и запросов из OpenAPI.
- `Mapper`: перевод backend DTO в текущие Swift-модели приложения.
- `Repository`: `AuthRepository`, `TripsRepository`, `PlanRepository`, `ExpensesRepository`, `WidgetRepository`.

Минимальный порядок внедрения:

1. Добавить `BackendConfig`, `APIClient`, `APIError`.
2. Добавить `AuthTokenStore` на Keychain.
3. Подключить `POST /api/v1/auth/yandex`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`, `GET /api/v1/me`.
4. Подключить read-only сценарии: список поездок, детали, дни, план, расходы, балансы, widget.
5. Подключить write-сценарии: создание, редактирование и мягкое удаление.
6. Перевести локальные stores на repositories, оставив `UserDefaults` только как cache/offline-слой.

## Базовый URL и окружения

Локально backend запускается на:

```text
http://localhost:8080
```

Для iOS Simulator обычно можно использовать:

```text
http://localhost:8080
```

Для физического iPhone нужен адрес Mac в локальной сети:

```text
http://<ip-macbook>:8080
```

В production должен использоваться только HTTPS. Для debug можно временно разрешить HTTP в `Info.plist` через App Transport Security, но это не должно попадать в production-конфигурацию.

## Авторизация и профиль

### POST /api/v1/auth/yandex

Назначение: обменять OAuth-токен Яндекса на backend-сессию.

Запрос:

```json
{
  "oauth_token": "token-from-yandex-login-sdk",
  "device_id": "ios-device-id",
  "device_name": "iPhone 15 Pro"
}
```

Ответ:

```json
{
  "access_token": "backend-access-token",
  "refresh_token": "backend-refresh-token",
  "token_type": "Bearer",
  "expires_in": 900,
  "user": {
    "id": "b7f0f40f-2f8d-4d7c-8e93-9c0f8f6ef9a0",
    "email": "user@example.com",
    "display_name": "Алиса",
    "avatar_url": "https://...",
    "role": "user"
  }
}
```

Что делать на iOS:

- сохранить `access_token` и `refresh_token` в Keychain;
- сохранить легкий профиль в memory state и, при необходимости, в cache;
- не хранить Яндекс OAuth-токен как основную сессию;
- использовать `user.role` для отображения админских функций, если они появятся.

Mapping:

| iOS поле | Backend поле | Комментарий |
|---|---|---|
| `AuthUserProfile.id` | `user.id` | UUID backend-пользователя |
| `displayName` | `user.display_name` | Основное имя в UI |
| `email` | `user.email` | Может быть пустым, UI должен это пережить |
| `avatarURL` | `user.avatar_url` | Может быть `null` |
| `provider` | константа `.yandexID` | Источник входа |
| `role` | `user.role` | `admin` или `user` |

### POST /api/v1/auth/refresh

Назначение: обновить короткоживущий access token.

Запрос:

```json
{
  "refresh_token": "backend-refresh-token"
}
```

iOS-логика:

- вызывать только после `401 TOKEN_EXPIRED` или перед запросом, если срок access token уже истек;
- при успешном refresh заменить оба токена;
- повторить исходный запрос один раз;
- если refresh вернул ошибку, разлогинить пользователя.

### POST /api/v1/auth/logout

Назначение: завершить refresh-сессию на backend.

Запрос:

```json
{
  "refresh_token": "backend-refresh-token"
}
```

iOS-логика:

- вызвать backend logout;
- даже если сеть недоступна, удалить локальные токены;
- очистить приватные caches;
- вернуть пользователя на экран входа.

### GET /api/v1/me и PATCH /api/v1/me

`GET /api/v1/me` нужен для восстановления сессии при старте приложения.

`PATCH /api/v1/me` нужен для изменения имени и аватара, если UI профиля позволит редактирование.

## Поездки

### GET /api/v1/trips

Назначение: получить список поездок текущего пользователя. Эта ручка должна питать каталог поездок.

Что важно для iOS:

- ручка не должна возвращать мягко удаленные поездки в обычном списке;
- карточка поездки уже содержит агрегированные данные, поэтому iOS не должен делать несколько запросов на каждую карточку;
- список можно cache-ировать локально для быстрого первого экрана.

Основной mapping:

| iOS `TravelTrip` | Backend `Trip` | Комментарий |
|---|---|---|
| `id` | `id` | UUID |
| `title` | `title` | Название поездки |
| `subtitle` | `date_range_label` или города | Текст для карточки |
| `cities` | `cities[].name` | Список городов |
| `participants` | `parties[].display_name` | Участники |
| `startDate` | `starts_on` | ISO date |
| `endDate` | `ends_on` | ISO date |
| `cover` | `cover_url` | Может быть `null` |
| `progress` | `schedule_progress` | Заполненность маршрута |

### POST /api/v1/trips

Назначение: создать поездку.

iOS должен отправлять минимально валидные поля: название, даты, города или хотя бы название и диапазон дат, если UI позволяет создать черновик.

После успешного создания:

- добавить поездку в локальный список;
- открыть экран деталей новой поездки;
- если запрос не прошел, показать ошибку и сохранить draft локально только если такой UX нужен.

### GET /api/v1/trips/{trip_id}

Назначение: получить полные данные поездки.

Использовать:

- при открытии деталей поездки;
- при pull-to-refresh;
- после изменения поездки, если backend возвращает неполный ответ на write-операции.

### PATCH /api/v1/trips/{trip_id}

Назначение: изменить базовые поля поездки.

Для iOS важно отправлять только измененные поля, если текущий DTO это поддерживает. Это снижает риск затереть данные, которые пользователь не редактировал.

### DELETE /api/v1/trips/{trip_id}

Назначение: мягко удалить поездку.

Backend не удаляет запись физически, а выставляет флаг удаления. Это нужно для будущего восстановления.

UX:

- перед удалением показать confirmation;
- после успеха убрать поездку из списка;
- показать snackbar/toast с текстом вроде `Поездка удалена`;
- когда появится endpoint восстановления, можно добавить действие `Восстановить`.

## Дни и план поездки

### GET /api/v1/trips/{trip_id}/days

Назначение: получить дни маршрута.

iOS использует это как основу календарной структуры: дата, подпись даты, город, порядок дня.

### GET /api/v1/trips/{trip_id}/plan-items

Назначение: получить все элементы плана поездки.

Рекомендуемый подход:

- запросить `days` и `plan-items` параллельно;
- сгруппировать `plan-items` по `day_id`;
- внутри дня сортировать по `starts_at`, затем по `sort_order`;
- если `starts_at` пустой, показывать элемент в соответствующем периоде или в блоке без точного времени.

Mapping:

| iOS `PlanItem` | Backend поле | Комментарий |
|---|---|---|
| `id` | `id` | UUID |
| `title` | `title` | Заголовок |
| `location` | `location_name` | Может быть пустым |
| `period` | `period` | `morning`, `afternoon`, `evening`, `night` |
| `startTime` | `starts_at` | ISO datetime, optional |
| `endTime` | `ends_at` | ISO datetime, optional |
| `notes` | `notes` | Optional |
| `hasTickets` | `has_tickets` | Для UI-индикатора |
| `bookingReference` | `booking_reference` | Optional |

### POST /api/v1/trips/{trip_id}/plan-items

Назначение: создать элемент плана.

iOS должен валидировать:

- непустой `title`;
- корректный интервал `ends_at > starts_at`, если обе даты заполнены;
- выбранный день принадлежит текущей поездке.

После создания лучше обновить список plan-items с backend или вставить returned item в локальный store.

### PATCH /api/v1/trips/{trip_id}/plan-items/{item_id}

Назначение: изменить элемент плана.

UX:

- optimistic update допустим, если есть rollback при ошибке;
- при `403` показать, что нет прав на редактирование;
- при `404` удалить элемент из локального списка, потому что он мог быть удален на другом устройстве.

### DELETE /api/v1/trips/{trip_id}/plan-items/{item_id}

Назначение: мягко удалить элемент плана.

После успеха убрать элемент из UI. Физически запись остается в базе.

### GET /api/v1/trips/{trip_id}/schedule-progress

Назначение: получить заполненность расписания по дням и периодам.

Это backend-read-model, чтобы iOS не пересчитывал сложную логику пересечений точного времени.

Использовать:

- для progress bar на карточке поездки;
- для индикаторов заполненности дня;
- для подсказок, где в маршруте есть свободные окна.

## Расходы и балансы

### GET /api/v1/trips/{trip_id}/expenses

Назначение: получить список расходов.

Важно: деньги приходят в minor units, то есть рубли/евро/доллары без `Double`-ошибок.

Пример:

```json
{
  "amount_minor": 125000,
  "currency": "RUB"
}
```

Для UI это `1 250,00 RUB`, если у валюты 2 знака после запятой.

Mapping:

| iOS поле | Backend поле | Комментарий |
|---|---|---|
| `id` | `id` | UUID |
| `title` | `title` | Название расхода |
| `amount` | `amount_minor` | Конвертировать через decimal formatter |
| `currency` | `currency` | ISO currency |
| `paidBy` | `paid_by_party_id` | Связать с участником |
| `shares` | `shares[]` | Явные доли участников |
| `date` | `spent_at` | Дата расхода |
| `category` | `category` | Optional |

### POST /api/v1/trips/{trip_id}/expenses

Назначение: создать расход.

iOS должен:

- принимать сумму как строку, а не `Double`;
- переводить сумму в `amount_minor`;
- отправлять `paid_by_party_id`;
- отправлять `shares`, если расход делится не поровну или backend требует явные доли.

### PATCH /api/v1/trips/{trip_id}/expenses/{expense_id}

Назначение: изменить расход.

После изменения нужно обновить не только список расходов, но и балансы, потому что одно изменение может поменять несколько итоговых сумм.

### DELETE /api/v1/trips/{trip_id}/expenses/{expense_id}

Назначение: мягко удалить расход.

После успеха:

- убрать расход из списка;
- заново запросить `GET /balances`;
- обновить summary на экране расходов.

### GET /api/v1/trips/{trip_id}/balances

Назначение: получить расчет, кто кому должен.

Это должно считаться на backend, потому что:

- backend знает точные доли;
- backend использует integer minor units;
- разные клиенты получат одинаковый результат.

iOS должен только красиво отобразить результат.

## Widget

### GET /api/v1/trips/{trip_id}/widget

Назначение: получить компактную read-model для WidgetKit.

WidgetKit не должен напрямую ходить в сеть. Основное приложение должно:

1. получить `widget` response;
2. сохранить JSON в App Group container, например `group.com.alisa.trip`;
3. вызвать обновление timeline;
4. widget читает только локальный cache.

Когда обновлять widget cache:

- после входа;
- после открытия поездки;
- после изменения плана или расходов;
- по background refresh, если он будет добавлен.

## Импорт локальных данных

### POST /api/v1/import/local-data

Назначение: перенести локальные данные iOS в backend.

Использовать один раз для миграции пользователей, у которых уже были локальные поездки.

UX:

- после первого успешного входа проверить, есть ли локальные поездки без backend ID;
- спросить пользователя или выполнить автоматический импорт, если продуктово это ожидаемо;
- после успешного импорта связать локальные записи с backend UUID;
- не импортировать повторно одни и те же записи.

## Роли и права

В проекте нужно учитывать два уровня прав.

Системная роль пользователя:

- `admin`;
- `user`.

Роль внутри конкретной поездки:

- `owner`;
- `editor`;
- `viewer`.

Системная роль отвечает за доступ к приложению и будущие служебные возможности. Роль внутри поездки отвечает за действия с конкретной поездкой. Один пользователь может быть `owner` одной поездки, `viewer` другой и при этом иметь системную роль `user`.

### Как это использовать на iOS

iOS не должен считать себя источником прав. Backend должен проверять права на каждой защищенной ручке. iOS использует роли только для UX:

- скрыть или disabled-кнопки, которые пользователь точно не может нажать;
- показать понятную ошибку, если backend вернул `403`;
- не показывать админские экраны пользователю с ролью `user`;
- не пытаться обойти backend-проверки локальной логикой.

### Матрица UI-действий

| Действие в iOS | Backend-проверка | Что показывать в UI |
|---|---|---|
| Смотреть список поездок | авторизованный пользователь | список доступных поездок |
| Создать поездку | `admin` или `user` | кнопка создания доступна |
| Открыть поездку | membership в поездке | экран деталей |
| Изменить поездку | `owner` или разрешенный `editor` | кнопка редактирования |
| Удалить поездку | `owner` | confirmation удаления |
| Восстановить поездку | будущий endpoint, `owner` или `admin` | действие восстановления, когда появится ручка |
| Смотреть план | `owner/editor/viewer` | read-only для `viewer` |
| Редактировать план | `owner/editor` | edit controls |
| Смотреть расходы | `owner/editor/viewer` | список и балансы |
| Редактировать расходы | `owner/editor` | add/edit/delete controls |
| Админские функции | `admin` | отдельный admin UI в будущем |

### Ошибки прав

iOS должен обрабатывать:

- `401`: пользователь не авторизован или access token истек;
- `403`: пользователь авторизован, но у него нет прав;
- `404`: объект не найден или недоступен пользователю;
- `409`: конфликт данных, например устаревшая версия или пересечение, если такая проверка появится;
- `422`: ошибка валидации запроса.

Для `403` лучше показывать текст: `У вас нет прав на это действие`. Для `404` в деталях поездки лучше возвращать пользователя к списку и обновлять список.

## Offline/cache поведение

На первом этапе лучше сделать backend source of truth и простой read cache:

- хранить последний успешный список поездок;
- хранить последние открытые детали поездки;
- при offline показывать cache с пометкой, что данные могут быть неактуальны;
- write-операции без сети не выполнять, пока не появится полноценная очередь синхронизации.

Если позже добавлять offline write:

- каждому локальному изменению нужен idempotency key;
- нужна очередь pending mutations;
- нужен conflict resolution;
- backend должен поддерживать версионирование или `updated_at` checks.

## Интеграционное тестирование

### Что проверять автоматически на iOS

Unit-тесты:

- `APIClient` правильно кодирует JSON;
- `APIClient` правильно декодирует success/error responses;
- `AuthInterceptor` добавляет `Authorization`;
- refresh вызывается при `401 TOKEN_EXPIRED`;
- refresh не уходит в бесконечный цикл;
- mapper корректно переводит backend DTO в Swift-модели;
- money formatter корректно отображает `amount_minor`;
- date parser корректно обрабатывает ISO date/datetime.

Repository-тесты с mocked transport:

- login через Yandex backend response сохраняет токены;
- logout удаляет токены;
- список поездок маппится в `TravelTrip`;
- создание поездки обновляет store;
- delete поездки убирает ее из списка;
- создание/редактирование plan item обновляет день;
- изменение expense перезапрашивает balances.

UI-тесты:

- пользователь без сессии видит экран входа;
- после mock-login открывается основной tab flow;
- список поездок отображает данные backend;
- удаление поездки показывает confirmation и убирает карточку;
- viewer не видит кнопки редактирования;
- editor видит редактирование плана и расходов, но не удаление поездки;
- owner видит delete trip;
- при `403` показывается понятная ошибка.

### Что проверять интеграционно с настоящим backend

Локальный сценарий:

1. Запустить backend:

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
docker compose up --build
```

2. Открыть Swagger:

```text
http://localhost:8081
```

3. Проверить health:

```bash
curl http://localhost:8080/live
curl http://localhost:8080/ready
```

4. Получить токен через local login или Yandex flow.
5. Выполнить сценарий: список поездок -> детали -> дни -> plan-items -> expenses -> balances -> widget.
6. Выполнить write-сценарии: создать поездку, изменить, добавить plan item, добавить expense, удалить expense, удалить поездку.
7. Проверить в DBeaver, что soft delete выставляет флаг, а не удаляет строку физически.

### Минимальный backend smoke-test для iOS

Команды можно запускать после получения `ACCESS_TOKEN`:

```bash
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/me
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/trips
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/days
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/plan-items
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/schedule-progress
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/expenses
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/balances
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/v1/trips/7a835df2-a238-4c4b-9f36-5da11a42b40e/widget
```

UUID `7a835df2-a238-4c4b-9f36-5da11a42b40e` - это demo trip из seed-миграции. В реальном UI нужно использовать id, который пришел из `GET /api/v1/trips`.

## UX-тестирование по функционалу приложения

### Вход и профиль

Проверить:

- первый запуск без сессии показывает экран входа;
- вход через Яндекс возвращает в основной flow;
- профиль показывает имя, email и avatar, если они есть;
- перезапуск приложения сохраняет сессию;
- logout возвращает на экран входа;
- при истекшем access token приложение незаметно делает refresh.

### Каталог поездок

Проверить:

- пустой список показывает нормальный empty state;
- список с demo-данными показывает карточки без скачков layout;
- pull-to-refresh обновляет данные;
- создание поездки добавляет карточку;
- мягкое удаление убирает карточку;
- после удаления и перезапуска удаленная поездка не возвращается в обычный список.

### Детали и план

Проверить:

- открытие поездки загружает детали, дни и plan-items;
- элементы плана правильно сгруппированы по дням;
- периоды `morning/afternoon/evening/night` отображаются по-русски;
- создание plan item появляется в правильном дне;
- изменение времени меняет порядок;
- удаление plan item убирает его из UI;
- schedule progress обновляется после изменений.

### Расходы

Проверить:

- суммы отображаются без ошибок округления;
- участники корректно подставляются по `party_id`;
- создание расхода меняет список расходов;
- изменение расхода меняет balances;
- удаление расхода обновляет balances;
- разные валюты отображаются отдельно и не смешиваются.

### Роли и права

Проверить минимум три пользователя или mock-сессии:

- `owner`: видит редактирование поездки, плана, расходов и удаление поездки;
- `editor`: видит редактирование плана и расходов, но не удаление поездки;
- `viewer`: видит данные, но не видит edit/delete controls;
- `admin`: если появятся admin-функции, видит их только при `user.role = admin`.

Важно отдельно проверить, что если кнопку скрыли в UI, backend все равно запрещает действие при прямом запросе с недостаточными правами.

## Backend-готовность для iOS

Сейчас ручки покрывают основной функционал приложения:

- вход и профиль;
- список поездок;
- детали поездки;
- создание, редактирование и мягкое удаление поездки;
- дни маршрута;
- элементы плана;
- заполненность расписания;
- расходы;
- балансы;
- данные для widget;
- импорт локальных данных.

Что стоит добавить следующим backend-шагом:

- обязательный `Authorization` для всех пользовательских ручек;
- проверку `trip_members` для доступа к конкретной поездке;
- endpoint восстановления поездки, например `POST /api/v1/trips/{trip_id}/restore`;
- endpoint управления участниками поездки;
- полноценные integration tests backend + Postgres;
- contract tests по OpenAPI, чтобы iOS и backend не расходились по DTO.

## Definition of Done для iOS-интеграции

Интеграцию можно считать готовой, когда:

- вход через Яндекс идет через backend, а не напрямую в профиль Яндекса;
- токены backend лежат в Keychain;
- все API-запросы используют единый `APIClient`;
- read-сценарии работают с demo seed-данными;
- create/update/delete работают и отражаются в PostgreSQL;
- soft delete не удаляет строки физически;
- роли управляют UX, но backend остается источником прав;
- есть unit-тесты мапперов, APIClient и auth refresh;
- есть UI-тесты ключевых flows;
- есть ручной smoke-test checklist для перед релизом.
