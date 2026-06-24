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

## Куда добавлять код в iOS

Сейчас в приложении много логики хранится в `mobile/ios/Trip/Models.swift`. Для backend-интеграции лучше не добавлять туда весь сетевой слой, иначе файл станет слишком большим и сложным для поддержки.

Рекомендуемая структура новых файлов:

```text
mobile/ios/Trip/Networking/BackendConfig.swift
mobile/ios/Trip/Networking/APIClient.swift
mobile/ios/Trip/Networking/APIError.swift
mobile/ios/Trip/Networking/AuthTokenStore.swift
mobile/ios/Trip/Networking/BackendDTO.swift
mobile/ios/Trip/Networking/BackendMappers.swift
mobile/ios/Trip/Networking/AuthRepository.swift
mobile/ios/Trip/Networking/TripsRepository.swift
mobile/ios/Trip/Networking/PlanRepository.swift
mobile/ios/Trip/Networking/ExpensesRepository.swift
mobile/ios/Trip/Networking/WidgetRepository.swift
```

Существующие файлы, которые нужно изменить:

| Файл | Что изменить |
|---|---|
| `mobile/ios/Trip/TripApp.swift` | Создать зависимости приложения или передать их в `ContentView`, если будет dependency container. |
| `mobile/ios/Trip/ContentView.swift` | Передать repositories/stores в экраны, добавить восстановление сессии при старте. |
| `mobile/ios/Trip/Features/Auth/AuthModels.swift` | Убрать прямой production-вызов `https://login.yandex.ru/info`, добавить backend login/refresh/logout/me. |
| `mobile/ios/Trip/Features/Auth/AuthViews.swift` | Оставить UI входа и профиля, подключить состояния loading/error от `AuthStore`. |
| `mobile/ios/Trip/Features/Trips/TripsViews.swift` | Загружать список поездок с backend, добавить loading/error/empty states, вызвать create/update/delete через repository. |
| `mobile/ios/Trip/Features/AppShell/TripWorkspaceViews.swift` | При открытии поездки запускать загрузку деталей, плана, расходов и widget cache. |
| `mobile/ios/Trip/Features/Plan/PlanViews.swift` | Создание, редактирование и удаление plan item отправлять на backend. |
| `mobile/ios/Trip/Features/Expenses/ExpenseViews.swift` | Создание, редактирование, удаление расходов и balances брать с backend. |
| `mobile/ios/Trip/Models.swift` | Постепенно оставить только UI/domain-модели и локальный cache, сетевые DTO вынести в `BackendDTO.swift`. |

Важно: после добавления новых `.swift` файлов их нужно добавить в target `Trip` в Xcode. Если файлы создаются через Xcode, это произойдет автоматически. Если через Finder или Git, нужно проверить `mobile/ios/Trip.xcodeproj/project.pbxproj`.

## Пошаговый план, после которого интеграция должна заработать

### Шаг 1. Добавить сетевой фундамент

Создать `BackendConfig.swift`:

```swift
struct BackendConfig {
    let baseURL: URL

    static let debug = BackendConfig(baseURL: URL(string: "http://localhost:8080")!)
}
```

Создать `APIError.swift`:

```swift
enum APIError: Error, Equatable {
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case validation(String?)
    case server(Int)
    case decoding
    case network(String)
}
```

Создать `APIClient.swift`:

- метод `send<RequestBody, ResponseBody>(path:method:body:requiresAuth:)`;
- JSON encoder/decoder с `snake_case`;
- автоматическое добавление `Authorization`;
- обработка `401` через refresh и один retry;
- единая обработка `403`, `404`, `422`, `5xx`.

Создать `AuthTokenStore.swift`:

- `save(accessToken:refreshToken:expiresIn:)`;
- `loadAccessToken()`;
- `loadRefreshToken()`;
- `clear()`;
- хранение через Keychain, не через `UserDefaults`.

### Шаг 2. Добавить DTO и mapper

Создать `BackendDTO.swift` и описать DTO по Swagger. Имена можно делать Swift-friendly, но поля должны совпадать через `CodingKeys`.

Минимальные группы DTO:

- `AuthResponseDTO`, `UserDTO`;
- `TripDTO`, `CityDTO`, `PartyDTO`;
- `TripDayDTO`;
- `PlanItemDTO`;
- `ScheduleProgressDTO`;
- `ExpenseDTO`, `ExpenseShareDTO`;
- `BalancesDTO`, `BalanceDTO`, `SettlementDTO`;
- `TripWidgetDTO`;
- request DTO для create/update ручек.

Создать `BackendMappers.swift`:

- `UserDTO -> AuthUserProfile`;
- `TripDTO -> TravelTrip`;
- `TripDayDTO + [PlanItemDTO] -> [TripDay]`;
- `PlanItemDTO -> PlanItem`;
- `ExpenseDTO -> ExpenseItem`;
- `BalancesDTO -> ExpenseSplitSummary` или новая server-driven модель балансов.

### Шаг 3. Подключить авторизацию

Изменить `AuthStore` в `mobile/ios/Trip/Features/Auth/AuthModels.swift`:

- добавить зависимость `AuthRepository`;
- `signInWithYandex()` должен запускать Yandex LoginSDK;
- `completeYandexSignIn(oauthToken:)` должен вызывать `AuthRepository.loginWithYandex(oauthToken:)`, а не `YandexIDAPI.profile`;
- `init()` должен пробовать восстановить профиль через `GET /api/v1/me`, если в Keychain есть access token;
- `signOut()` должен вызывать `POST /api/v1/auth/logout`, затем чистить Keychain и локальный профиль.

### Шаг 4. Подключить каталог поездок

Изменить `TripCatalogStore` в `mobile/ios/Trip/Models.swift` или вынести его в отдельный файл:

- добавить `isLoading`, `errorMessage`;
- добавить `loadTrips() async`;
- `add(_:)`, `update(_:)`, `delete(_:)` должны иметь backend-версии: `createTrip`, `updateTrip`, `deleteTrip`;
- локальный `UserDefaults` оставить только как cache последнего успешного списка.

Изменить `TripsView` в `mobile/ios/Trip/Features/Trips/TripsViews.swift`:

- в `.task` вызвать `store.loadTrips()`;
- добавить pull-to-refresh;
- на сохранение `TripEditorView` вызывать async create/update;
- на удаление вызывать backend soft delete;
- показывать loading/error/empty states.

### Шаг 5. Подключить детали поездки, дни и план

Изменить `TripWorkspaceView` в `mobile/ios/Trip/Features/AppShell/TripWorkspaceViews.swift`:

- при `.onAppear` вызвать загрузку details/days/plan-items/schedule-progress;
- при смене `trip` отменять старые запросы или игнорировать устаревшие ответы;
- передавать в `PlanTabView` уже загруженный `TripStore`.

Изменить `TripStore`:

- добавить `loadTripWorkspace(tripID:) async`;
- внутри параллельно вызвать `GET /trips/{trip_id}`, `GET /days`, `GET /plan-items`, `GET /schedule-progress`;
- собрать `[TripDay]` через mapper;
- write-операции `add/update/delete PlanItem` отправлять на backend.

### Шаг 6. Подключить расходы и балансы

Изменить `ExpenseStore`:

- добавить `loadExpensesAndBalances(tripID:) async`;
- `addExpense`, `updateExpense`, `deleteExpense` должны вызывать backend;
- после каждой write-операции перезапрашивать `GET /balances`;
- локальный расчет оставить только для preview/offline fallback, но не как source of truth.

Изменить `ExpensesView`:

- в `.task` загрузить расходы и балансы для активной поездки;
- отправлять форму `ExpenseEntryView` в `POST /expenses`;
- после удаления строки вызвать `DELETE /expenses/{expense_id}`;
- показывать balances из backend.

### Шаг 7. Подключить widget cache

Создать `WidgetRepository.swift`:

- `getTripWidget(tripID:) async throws -> TripWidgetDTO`.

В основном приложении после загрузки поездки:

- вызвать `GET /api/v1/trips/{trip_id}/widget`;
- сохранить JSON в App Group `group.com.alisa.trip`;
- вызвать reload timeline;
- сам widget не должен ходить в сеть.

### Шаг 8. Добавить импорт локальных данных

После успешного первого backend-login:

- проверить, есть ли локальные поездки/план/расходы без backend id;
- собрать payload для `POST /api/v1/import/local-data`;
- после успешного импорта заменить локальные id на backend id;
- поставить флаг `localImportCompleted`, чтобы не импортировать повторно.

## Полная карта endpoint -> iOS

| Endpoint | Repository method | Экран/Store | Файлы | Когда вызывать | Что обновлять |
|---|---|---|---|---|---|
| `GET /live` | `HealthRepository.live()` или debug curl | Не нужен в production UI | Новый debug/service файл, если нужен | Только для локальной проверки backend | Ничего в UI |
| `GET /ready` | `HealthRepository.ready()` или debug curl | Не нужен в production UI | Новый debug/service файл, если нужен | Перед ручным тестированием или debug diagnostics | Ничего в UI |
| `POST /api/v1/auth/register` | `AuthRepository.register(...)` | Debug/local auth screen, если добавим | `AuthModels.swift`, `AuthViews.swift` | Только если нужен email/password flow | `AuthStore.profile`, Keychain |
| `POST /api/v1/auth/login` | `AuthRepository.login(...)` | Debug/local auth screen, если добавим | `AuthModels.swift`, `AuthViews.swift` | Только если нужен email/password flow | `AuthStore.profile`, Keychain |
| `POST /api/v1/auth/yandex` | `AuthRepository.loginWithYandex(oauthToken:deviceID:deviceName:)` | `AuthLandingView`, `AuthStore` | `AuthModels.swift`, `AuthViews.swift`, `AuthRepository.swift` | После успешного Yandex LoginSDK | Keychain, `AuthUserProfile`, root navigation |
| `POST /api/v1/auth/refresh` | `AuthRepository.refresh(refreshToken:)` | Автоматически в `APIClient` | `APIClient.swift`, `AuthTokenStore.swift`, `AuthRepository.swift` | При `401 TOKEN_EXPIRED` или истекшем access token | Keychain, retry исходного запроса |
| `POST /api/v1/auth/logout` | `AuthRepository.logout(refreshToken:)` | `ProfileTabView`, `AuthStore` | `AuthModels.swift`, `AuthViews.swift`, `AuthRepository.swift` | Нажатие `Выйти` | Очистить Keychain/cache/profile |
| `GET /api/v1/me` | `AuthRepository.me()` | `ContentView`, `ProfileTabView`, `AuthStore` | `ContentView.swift`, `AuthModels.swift`, `AuthRepository.swift` | Старт приложения, открытие профиля, после refresh | `AuthStore.profile` |
| `PATCH /api/v1/me` | `AuthRepository.updateMe(...)` | Будущий экран редактирования профиля | `AuthViews.swift`, `AuthRepository.swift` | Сохранение имени/avatar | `AuthStore.profile` |
| `GET /api/v1/trips` | `TripsRepository.listTrips()` | `TripsView`, `TripCatalogStore` | `TripsViews.swift`, `Models.swift`, `TripsRepository.swift` | Старт после login, вкладка поездок, pull-to-refresh | `TripCatalogStore.trips` |
| `POST /api/v1/trips` | `TripsRepository.createTrip(...)` | `TripEditorView`, `TripCatalogStore` | `TripsViews.swift`, `Models.swift`, `TripsRepository.swift` | Сохранение новой поездки | Добавить `TravelTrip`, открыть детали |
| `GET /api/v1/trips/{trip_id}` | `TripsRepository.getTrip(id:)` | `TripWorkspaceView`, header деталей | `TripWorkspaceViews.swift`, `Models.swift`, `TripsRepository.swift` | Открытие поездки, refresh деталей | Header, selected trip cache |
| `PATCH /api/v1/trips/{trip_id}` | `TripsRepository.updateTrip(id:request:)` | `TripEditorView`, `TripCatalogStore` | `TripsViews.swift`, `Models.swift`, `TripsRepository.swift` | Сохранение редактирования поездки | Обновить карточку и header |
| `DELETE /api/v1/trips/{trip_id}` | `TripsRepository.deleteTrip(id:)` | `TripsView`, `TripCardView`, `TripCatalogStore` | `TripsViews.swift`, `Models.swift`, `TripsRepository.swift` | Подтвержденное удаление поездки | Убрать из списка, сбросить selectedTripID |
| `GET /api/v1/trips/{trip_id}/days` | `PlanRepository.listDays(tripID:)` | `PlanTabView`, `TripStore` | `PlanViews.swift`, `Models.swift`, `PlanRepository.swift` | Открытие поездки, refresh плана | `TripStore.days` skeleton |
| `GET /api/v1/trips/{trip_id}/plan-items` | `PlanRepository.listPlanItems(tripID:)` | `TimelineView`, `TripStore` | `PlanViews.swift`, `Models.swift`, `PlanRepository.swift` | Открытие поездки, после write | `TripDay.items` |
| `POST /api/v1/trips/{trip_id}/plan-items` | `PlanRepository.createPlanItem(tripID:request:)` | `PlanItemEditorView`, `TripStore` | `PlanViews.swift`, `Models.swift`, `PlanRepository.swift` | Сохранение нового события | Вставить item в день, обновить progress |
| `PATCH /api/v1/trips/{trip_id}/plan-items/{item_id}` | `PlanRepository.updatePlanItem(tripID:itemID:request:)` | `PlanItemEditorView`, `TimelinePlanCard`, `TripStore` | `PlanViews.swift`, `Models.swift`, `PlanRepository.swift` | Сохранение редактирования события | Обновить item, пересортировать timeline |
| `DELETE /api/v1/trips/{trip_id}/plan-items/{item_id}` | `PlanRepository.deletePlanItem(tripID:itemID:)` | `TimelinePlanCard`, `PlanItemEditorView`, `TripStore` | `PlanViews.swift`, `Models.swift`, `PlanRepository.swift` | Подтвержденное удаление события | Убрать item, обновить progress |
| `GET /api/v1/trips/{trip_id}/schedule-progress` | `PlanRepository.getScheduleProgress(tripID:)` | `TripProgressBar`, `EuropeTripStatusWidget`, `MonthCalendarView` | `AppStyle.swift`, `PlanViews.swift`, `Models.swift`, `PlanRepository.swift` | Открытие поездки, после изменения плана | Progress модели |
| `GET /api/v1/trips/{trip_id}/expenses` | `ExpensesRepository.listExpenses(tripID:)` | `ExpensesView`, `ExpenseStore` | `ExpenseViews.swift`, `Models.swift`, `ExpensesRepository.swift` | Открытие вкладки трат, refresh | `ExpenseStore.expenses` |
| `POST /api/v1/trips/{trip_id}/expenses` | `ExpensesRepository.createExpense(tripID:request:)` | `ExpenseEntryView`, `ExpenseStore` | `ExpenseViews.swift`, `Models.swift`, `ExpensesRepository.swift` | Сохранение нового расхода | Добавить расход, обновить balances |
| `PATCH /api/v1/trips/{trip_id}/expenses/{expense_id}` | `ExpensesRepository.updateExpense(tripID:expenseID:request:)` | Будущий edit expense flow, `ExpenseRowView` | `ExpenseViews.swift`, `Models.swift`, `ExpensesRepository.swift` | Сохранение редактирования расхода | Обновить расход, обновить balances |
| `DELETE /api/v1/trips/{trip_id}/expenses/{expense_id}` | `ExpensesRepository.deleteExpense(tripID:expenseID:)` | `ExpenseRowView`, `ExpenseStore` | `ExpenseViews.swift`, `Models.swift`, `ExpensesRepository.swift` | Удаление расхода из истории | Убрать расход, обновить balances |
| `GET /api/v1/trips/{trip_id}/balances` | `ExpensesRepository.getBalances(tripID:)` | `ExpenseTotalsView`, `ExpenseSplitView`, `ExpenseStore` | `ExpenseViews.swift`, `Models.swift`, `ExpensesRepository.swift` | Открытие трат, после любого write расхода | Server balances/settlements |
| `GET /api/v1/trips/{trip_id}/widget` | `WidgetRepository.getTripWidget(tripID:)` | Основное приложение обновляет WidgetKit cache | `WidgetRepository.swift`, widget-файлы | После открытия поездки и после изменений | App Group JSON для widget |
| `POST /api/v1/import/local-data` | `ImportRepository.importLocalData(...)` | `AuthStore` или onboarding после login | `AuthModels.swift`, `Models.swift`, `ImportRepository.swift` | Первый вход пользователя с локальными данными | Связать local data с backend ids |

## DTO и mapping по всем ручкам

### Health: `GET /live`, `GET /ready`

Эти ручки нужны не для пользовательского UI, а для проверки, что backend поднят.

Mapping:

| Backend | iOS |
|---|---|
| `status` | debug text или игнорировать |
| `checks.database` в `/ready` | debug diagnostics |

В iOS production их можно не добавлять. Для debug можно сделать скрытый diagnostics screen.

### Local auth: `POST /auth/register`, `POST /auth/login`

Эти ручки нужны, если в приложении будет вход по email/password. Сейчас основной flow - Яндекс ID, поэтому local auth можно оставить для debug или внутреннего тестирования.

Request mapping:

| Backend request | iOS источник |
|---|---|
| `email` | поле email на debug auth screen |
| `password` | secure field |
| `display_name` | optional profile field |
| `device_id` | installation id |
| `device_name` | `UIDevice.current.name` |

Response mapping такой же, как у `POST /auth/yandex`: токены в Keychain, `user` в `AuthUserProfile`.

### Auth response: `POST /auth/yandex`, `POST /auth/refresh`

Response mapping:

| Backend DTO | Swift DTO | UI/domain |
|---|---|---|
| `access_token` | `AuthResponseDTO.accessToken` | Keychain |
| `refresh_token` | `AuthResponseDTO.refreshToken` | Keychain |
| `token_type` | `AuthResponseDTO.tokenType` | Проверить, что `Bearer` |
| `expires_in` | `AuthResponseDTO.expiresIn` | Expiration для refresh |
| `user.id` | `UserDTO.id` | `AuthUserProfile.id` |
| `user.email` | `UserDTO.email` | `AuthUserProfile.email` |
| `user.display_name` | `UserDTO.displayName` | `AuthUserProfile.displayName` |
| `user.avatar_url` | `UserDTO.avatarURL` | `AuthUserProfile.avatarURL` |
| `user.role` | `UserDTO.role` | `AuthUserProfile.role` или отдельное поле |

В текущем `AuthUserProfile` нет поля `role`. Его нужно добавить:

```swift
var role: UserRole
```

И enum:

```swift
enum UserRole: String, Codable {
    case admin
    case user
}
```

### Profile: `GET /me`, `PATCH /me`

`GET /me` использует тот же `UserDTO -> AuthUserProfile` mapper.

`PATCH /me` нужен для будущего редактирования профиля.

Request mapping для `PATCH /me`:

| Backend request | Экран | Файл |
|---|---|---|
| `display_name` | будущий edit profile sheet | `AuthViews.swift` |
| `avatar_url` | будущий avatar editor | `AuthViews.swift` |

После success обновить `AuthStore.profile`.

### Trips: list/get/create/update/delete

Swift DTO:

```swift
struct TripDTO: Decodable {
    let id: UUID
    let title: String
    let startsOn: Date
    let endsOn: Date
    let cities: [CityDTO]
    let parties: [PartyDTO]
    let coverURL: URL?
    let scheduleProgress: TripProgressDTO?
}
```

Mapping в текущий `TravelTrip`:

| Backend | `TravelTrip` | Где используется |
|---|---|---|
| `id` | `id` | `TripsView`, `TripWorkspaceView` |
| `title` | `title` | `TripCardView`, header |
| `starts_on` | `startDate` | карточка, editor, header |
| `ends_on` | `endDate` | карточка, editor, header |
| `cities[].name` | `cities` | карточка, editor, plan city fallback |
| `parties[].display_name` | `participants` | header, expenses participants |

Что стоит добавить в `TravelTrip`, чтобы не терять backend-данные:

```swift
var coverURL: URL?
var currentUserTripRole: TripMemberRole?
var scheduleProgress: TripProgress?
```

Где использовать:

- `TripsView`: `GET /trips`, `POST /trips`, `PATCH /trips`, `DELETE /trips`;
- `TripCardView`: данные карточки из `TravelTrip`;
- `TripEditorView`: create/update request;
- `ContentView`: selected trip id;
- `TripWorkspaceHeader`: `GET /trips/{trip_id}` при открытии.

Create/update request mapping:

| Поле формы `TripEditorView` | Backend request |
|---|---|
| `title` | `title` |
| `startDate` | `starts_on` |
| `endDate` | `ends_on` |
| выбранные города | `cities` или `city_names`, в зависимости от OpenAPI request |
| участники | `parties` или `participant_names`, в зависимости от OpenAPI request |

Delete:

- `DELETE /trips/{trip_id}` не удаляет физически;
- после успеха вызвать `TripCatalogStore.deleteLocal(tripID:)`;
- если удалили выбранную поездку, выбрать первую доступную или перейти в каталог.

### Days: `GET /trips/{trip_id}/days`

Swift DTO:

```swift
struct TripDayDTO: Decodable {
    let id: UUID
    let date: Date
    let cityName: String?
    let sortOrder: Int
}
```

Текущий `TripDay.id` - `Int`, а backend id - UUID. Чтобы корректно редактировать данные, нужно добавить backend id:

```swift
struct TripDay {
    var backendID: UUID?
}
```

Mapping:

| Backend | `TripDay` |
|---|---|
| `id` | `backendID` |
| `sort_order` | `id` или отдельный `sortOrder` |
| `date` | `date`, `dateKey` |
| `city_name` | `city` |
| `items` | заполняется после `GET /plan-items` |

Где использовать:

- `TripStore.loadTripWorkspace(tripID:)`;
- `MonthCalendarView`;
- `TimelineView`.

### Plan items: list/create/update/delete

Swift DTO:

```swift
struct PlanItemDTO: Decodable {
    let id: UUID
    let dayID: UUID
    let title: String
    let locationName: String?
    let period: String?
    let startsAt: Date?
    let endsAt: Date?
    let notes: String?
    let hasTickets: Bool
    let bookingReference: String?
    let category: String?
    let sortOrder: Int?
}
```

Текущий `PlanItem.id` - `UUID`, его можно напрямую связать с backend `id`.

Mapping:

| Backend | `PlanItem` | Где отображается |
|---|---|---|
| `id` | `id` | `TimelinePlanCard`, editor |
| `day_id` | день через `TripDay.backendID` | группировка по дням |
| `title` | `title` | карточка события |
| `location_name` | `city` или новое `locationName` | карточка/editor |
| `category` | `PlanCategory` | иконка/цвет |
| `period` | период fallback | блок дня |
| `starts_at` | `startDate` + `startTime` | timeline |
| `ends_at` | `endDate` + `endTime` | timeline |
| `has_tickets` | `needsTicket` | ticket icon |
| `ticket_bought` или ticket status | `ticketBought` | ticket icon |
| `notes` | новое поле `notes` | будущие детали |
| `booking_reference` | новое поле | будущие билеты |

Что нужно добавить в модели:

- `TripDay.backendID: UUID?`;
- возможно `PlanItem.backendDayID: UUID?`;
- `PlanItem.notes: String?`, если заметки нужны в UI;
- mapper `period` между backend enum и русскими периодами.

Где использовать:

- `PlanTabView`: загрузка и отображение;
- `MonthCalendarView`: дни и progress;
- `TimelineView`: список событий;
- `PlanItemEditorView`: create/update;
- `TimelinePlanCard`: delete/edit.

Write request mapping из `PlanItemEditorView`:

| Поле editor | Backend request |
|---|---|
| `title` | `title` |
| выбранный день | `day_id` |
| `city/location` | `location_name` |
| `category` | `category` |
| `startDate + startTime` | `starts_at` |
| `endDate + endTime` | `ends_at` |
| `needsTicket` | `has_tickets` |
| `ticketBought` | ticket status поле, если есть в DTO |

После create/update/delete нужно перезапросить `GET /schedule-progress`.

### Schedule progress: `GET /trips/{trip_id}/schedule-progress`

Эта ручка должна заменить локальный расчет заполненности там, где нужен server truth.

Mapping:

| Backend | iOS |
|---|---|
| общий процент поездки | `TravelTrip.scheduleProgress` или `TripProgress` |
| прогресс по дням | `TripDay.progress` или словарь `[dayID: progress]` |
| прогресс по периодам | индикаторы в `MonthCalendarView`/future UI |

Где использовать:

- `TripProgressBar` в `Shared/AppStyle.swift`;
- `EuropeTripStatusWidget` в `PlanViews.swift`;
- `TripCardView` в `TripsViews.swift`, если карточка показывает прогресс;
- `MonthCalendarView`, если нужны day indicators.

### Expenses: list/create/update/delete

Текущий `ExpenseItem` использует `Double amount` и имена участников. Backend использует `amount_minor` и ids участников. Для корректной интеграции нужно добавить связь с backend party id.

Рекомендуемые изменения:

```swift
struct TripParticipant: Identifiable, Codable, Equatable {
    let id: UUID
    let displayName: String
}
```

И в `TravelTrip`:

```swift
var partyIDsByName: [String: UUID]
```

Лучше полноценнее:

```swift
var participantsDetailed: [TripParticipant]
```

Expense DTO:

```swift
struct ExpenseDTO: Decodable {
    let id: UUID
    let title: String
    let amountMinor: Int
    let currency: String
    let paidByPartyID: UUID
    let spentAt: Date
    let category: String?
    let shares: [ExpenseShareDTO]
}
```

Mapping:

| Backend | `ExpenseItem` | Комментарий |
|---|---|---|
| `id` | `id` | UUID |
| `trip_id` | `tripID` | UUID |
| `title` | `title` | название |
| `amount_minor` | `amount` | конвертировать в Decimal/Double для текущего UI |
| `currency` | `ExpenseCurrency` | enum |
| `paid_by_party_id` | `participantName` через participant lookup | лучше добавить `paidByPartyID` |
| `shares[].party_id` | `involvedParticipantNames` через lookup | лучше добавить shares model |
| `spent_at` | `createdAt` | дата |

Что лучше поменять в iOS-модели:

- заменить деньги с `Double` на `Decimal` или хранить `amountMinor: Int`;
- добавить `paidByPartyID`;
- добавить `shares: [ExpenseShare]`;
- оставить `participantName` только как computed field для UI.

Где использовать:

- `ExpensesView`: загрузка и общий screen state;
- `ExpenseEntryView`: create request;
- `ExpenseRowView`: delete/edit;
- `ExpenseTotalsView`: totals из backend или derived from expenses;
- `ExpenseSplitView`: balances из `GET /balances`.

После create/update/delete:

1. обновить список расходов;
2. вызвать `GET /balances`;
3. обновить summary.

### Balances: `GET /trips/{trip_id}/balances`

Backend должен быть source of truth для балансов.

Mapping:

| Backend | iOS |
|---|---|
| `balances[].party_id` | найти participant display name |
| `balances[].currency` | `ExpenseCurrency` |
| `balances[].paid_minor` | `ExpenseBalance.paid` |
| `balances[].share_minor` | `ExpenseBalance.share` |
| `balances[].balance_minor` | `ExpenseBalance.balance` |
| `settlements[].from_party_id` | `ExpenseSettlement.from` |
| `settlements[].to_party_id` | `ExpenseSettlement.to` |
| `settlements[].amount_minor` | `ExpenseSettlement.amount` |

Где использовать:

- `ExpenseTotalsView` для totals;
- `ExpenseSplitView` для balances и settlements;
- `ExpenseBalanceRow`;
- `ExpenseSettlementRow`.

Важно: если текущий UI принимает `Double`, mapper должен конвертировать minor units только в одном месте. Не размазывать деление на 100 по экранам.

### Widget: `GET /trips/{trip_id}/widget`

Mapping зависит от текущей модели widget extension. Цель - сохранить готовый компактный JSON в App Group.

Где добавлять:

- новый `WidgetRepository.swift`;
- код записи в App Group можно держать в `WidgetCacheWriter.swift`;
- вызов из `TripWorkspaceView.onAppear`, после изменения plan item и после изменения expense.

Что писать в App Group:

- trip title;
- date range;
- next plan item;
- progress;
- expenses summary, если нужен в widget;
- `updatedAt`.

Widget extension читает только файл/cache и не использует `APIClient`.

### Import local data: `POST /import/local-data`

Где использовать:

- `AuthStore` после первого успешного login;
- отдельный `ImportRepository.swift`;
- локальные данные брать из `TripCatalogStore`, `TripStore`, `ExpenseStore`.

Mapping:

| Локальная модель | Backend import |
|---|---|
| `TravelTrip` | trip payload |
| `TripDay` | days payload |
| `PlanItem` | plan items payload |
| `ExpenseItem` | expenses payload |
| participants names | parties payload |

После успешного импорта:

- сохранить backend ids в локальные модели;
- обновить stores через обычные `GET /trips`, `GET /days`, `GET /plan-items`, `GET /expenses`;
- поставить локальный флаг, что импорт выполнен.

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
