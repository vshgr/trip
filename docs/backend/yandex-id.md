# Яндекс ID для iOS и Backend

Документ описывает, что должна сделать iOS-команда для подключения Яндекс ID, что должно быть настроено в кабинете Яндекса и как совместить mobile-flow с backend-сессией Trip.

## Главный принцип

iOS использует Яндекс ID только для получения OAuth-токена пользователя. После этого iOS сразу отправляет токен на backend:

```http
POST /api/v1/auth/yandex
```

Backend проверяет токен у Яндекса, создает или находит пользователя в нашей базе и возвращает собственные `access_token` и `refresh_token`. Дальше приложение работает только с backend-токенами.

Такой flow нужен, чтобы:

- роли и права жили на backend;
- поездки были привязаны к backend-пользователю, а не к локальному профилю;
- можно было поддерживать refresh/logout/session invalidation;
- можно было позже добавить другие провайдеры авторизации;
- iOS не хранил Яндекс OAuth-токен как постоянную сессию.

## Что нужно подготовить в Apple Developer

Для регистрации iOS-приложения в Яндексе нужны данные Apple Developer.

### Bundle ID

Bundle ID берется из Xcode:

```text
Target Trip -> Signing & Capabilities -> Bundle Identifier
```

В текущем проекте основной Bundle ID выглядит как:

```text
com.alisa.trip
```

Widget extension имеет отдельный Bundle ID:

```text
com.alisa.trip.TripWidget
```

Для Яндекс ID нужен Bundle ID основного приложения, то есть `com.alisa.trip`, если в Xcode он не был изменен.

### Team ID

Team ID берется из Apple Developer:

```text
Apple Developer -> Membership details -> Team ID
```

Также его можно увидеть в Xcode:

```text
Xcode -> Settings -> Accounts -> Apple ID -> Team -> Team ID
```

Это не обычный email Apple ID. Это идентификатор команды разработчика, обычно строка из 10 символов.

### App ID

Если Яндекс просит Apple ID / App ID для iOS, обычно имеется в виду связка:

```text
<TEAM_ID>.<BUNDLE_ID>
```

Пример:

```text
A1B2C3D4E5.com.alisa.trip
```

Где:

- `A1B2C3D4E5` - Team ID из Apple Developer;
- `com.alisa.trip` - Bundle ID основного приложения.

## Что нужно настроить в кабинете Яндекса

1. Открыть страницу регистрации OAuth-приложения Яндекс ID.
2. Создать приложение для Trip.
3. Добавить платформу iOS.
4. Указать Bundle ID основного приложения.
5. Указать Team ID или App ID, если форма Яндекса это требует.
6. Включить доступ к базовому профилю.
7. Включить доступ к email, если он нужен в профиле Trip.
8. Сохранить `Client ID`.

Официальные страницы:

- регистрация приложения: `https://yandex.ru/dev/id/doc/ru/register-client`
- iOS LoginSDK: `https://yandex.ru/dev/id/doc/ru/mobileauthsdk/ios/sdk-ios-main`
- информация о пользователе: `https://yandex.ru/dev/id/doc/ru/user-information`

## Что нужно добавить в iOS

### 1. Подключить Yandex LoginSDK

Подключить SDK способом, который рекомендует Яндекс для текущей версии iOS-проекта. Обычно это Swift Package Manager или CocoaPods.

После подключения нужно убедиться, что:

- SDK доступен в основном target `Trip`;
- SDK не подключается к widget extension;
- проект собирается на simulator и device.

### 2. Добавить Client ID

`Client ID` из кабинета Яндекса нужно добавить в конфигурацию приложения.

Рекомендуемый вариант:

- для debug хранить в `.xcconfig` или debug config;
- для production хранить в production config;
- не хардкодить секреты в Swift-файлах;
- не путать Yandex `Client ID` и backend base URL.

Пример логики:

```swift
struct YandexIDConfig {
    let clientID: String
}
```

### 3. Настроить URL schemes / redirect

Если Yandex LoginSDK требует URL scheme, его нужно добавить в `Info.plist` основного приложения.

Проверить:

- callback возвращает пользователя обратно в Trip;
- callback работает после холодного старта приложения;
- callback не нужен widget extension.

Точные значения нужно брать из документации SDK и настроек приложения в кабинете Яндекса.

### 4. Получить OAuth token

После успешного входа SDK должен вернуть OAuth token.

Этот токен нужен только для одного действия:

```http
POST /api/v1/auth/yandex
```

Не нужно использовать этот токен для постоянных запросов Trip API.

### 5. Отправить token на backend

Запрос:

```json
{
  "oauth_token": "token-from-yandex-login-sdk",
  "device_id": "ios-device-id",
  "device_name": "iPhone 15 Pro"
}
```

Поля:

- `oauth_token`: OAuth token, который вернул Yandex LoginSDK.
- `device_id`: стабильный id установки приложения или устройства. Нужен для refresh-сессий и будущего управления устройствами.
- `device_name`: человекочитаемое имя устройства для логов и будущего UI сессий.

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

### 6. Сохранить backend-сессию

iOS должен сохранить:

- `access_token` в Keychain;
- `refresh_token` в Keychain;
- срок жизни access token в памяти или secure storage;
- профиль пользователя в memory state и, при необходимости, в cache.

Нельзя хранить токены только в `UserDefaults`.

### 7. Использовать backend access token

Все запросы к Trip API должны идти с заголовком:

```http
Authorization: Bearer <access_token>
```

Пример:

```http
GET /api/v1/trips
Authorization: Bearer backend-access-token
```

### 8. Обновлять access token

Если backend вернул `401 TOKEN_EXPIRED`, iOS вызывает:

```http
POST /api/v1/auth/refresh
```

```json
{
  "refresh_token": "backend-refresh-token"
}
```

После успешного refresh:

- заменить оба токена в Keychain;
- повторить исходный запрос один раз;
- если повторный запрос снова неуспешен, не уходить в бесконечный retry.

### 9. Logout

При выходе:

```http
POST /api/v1/auth/logout
```

```json
{
  "refresh_token": "backend-refresh-token"
}
```

После этого iOS удаляет локальные токены и cache профиля. Если logout-запрос не дошел до backend из-за сети, локальные токены все равно нужно удалить.

## Что уже есть на backend

Backend уже поддерживает:

- `POST /api/v1/auth/yandex`;
- проверку OAuth token через Яндекс;
- создание пользователя, если его еще нет;
- связку Яндекс-аккаунта с пользователем в `user_identity_providers`;
- выдачу backend `access_token` и `refresh_token`;
- `POST /api/v1/auth/refresh`;
- `POST /api/v1/auth/logout`;
- `GET /api/v1/me`;
- роль пользователя `admin` или `user` в auth/me response.

## Как backend обрабатывает Яндекс-профиль

1. Backend получает `oauth_token` от iOS.
2. Backend вызывает Яндекс API профиля.
3. Backend получает внешний provider user id.
4. Backend ищет связку в `user_identity_providers`.
5. Если связка есть, backend использует найденного пользователя.
6. Если связки нет, backend создает пользователя или связывает с существующим по email, если такая логика включена.
7. Backend сохраняет provider, provider user id и профильные поля.
8. Backend возвращает собственную сессию Trip.

## Роли после входа через Яндекс

Новый пользователь получает системную роль:

```text
user
```

Роль `admin` назначается только на backend или через миграции/админский механизм. iOS не должен сам назначать роль.

Внутри поездок права определяются через membership:

- `owner`;
- `editor`;
- `viewer`.

iOS может использовать роли для отображения интерфейса, но окончательное решение всегда принимает backend.

## Обработка ошибок на iOS

### Пользователь отменил вход

Показать обычный экран входа без ошибки уровня alert. Можно показать нейтральный текст, если пользователь нажал кнопку входа и вернулся назад.

### Яндекс SDK вернул ошибку

Показать: `Не удалось войти через Яндекс. Попробуйте еще раз.`

В debug-лог можно записать техническую причину, но не токены.

### Backend не принял oauth_token

Возможные причины:

- токен истек;
- token не от того приложения;
- Яндекс недоступен;
- backend не может проверить профиль.

UX: показать повторный вход через Яндекс.

### Refresh token недействителен

iOS должен удалить токены и вернуть пользователя на экран входа.

### Нет сети

Если пользователь уже был авторизован:

- показать cached данные, если они есть;
- write-действия временно заблокировать или показать ошибку сети.

Если пользователь только входит:

- показать ошибку сети и оставить на экране входа.

## Проверка интеграции

### Локальная проверка backend

Запустить backend:

```bash
cd /Users/d.a.tasbauova/Documents/trip/backend
docker compose up --build
```

Проверить:

```bash
curl http://localhost:8080/live
curl http://localhost:8080/ready
```

Swagger:

```text
http://localhost:8081
```

### Проверка через Swagger

1. Открыть `http://localhost:8081`.
2. Найти `POST /api/v1/auth/yandex`.
3. Передать реальный `oauth_token`, полученный на iOS.
4. Скопировать `access_token`.
5. Выполнить `GET /api/v1/me` с `Authorization: Bearer <access_token>`.
6. Выполнить `GET /api/v1/trips`.

### Проверка на iOS Simulator

Сценарии:

- первый вход через Яндекс;
- возврат из Яндекс SDK обратно в приложение;
- успешный обмен Яндекс token на backend token;
- перезапуск приложения сохраняет backend-сессию;
- истекший access token обновляется через refresh;
- logout удаляет сессию;
- после logout пользователь не может открыть поездки без нового входа.

### Проверка на физическом устройстве

Нужно использовать backend URL с IP MacBook:

```text
http://<ip-macbook>:8080
```

Проверить:

- устройство и MacBook в одной сети;
- firewall не блокирует порт `8080`;
- App Transport Security разрешает debug HTTP;
- callback Яндекса возвращает именно в установленное приложение.

## Автоматические тесты для iOS

Unit-тесты:

- Yandex auth response маппится в `AuthUserProfile`;
- backend auth response сохраняет токены;
- `APIClient` добавляет Bearer token;
- `401 TOKEN_EXPIRED` вызывает refresh;
- refresh retry выполняется один раз;
- logout чистит Keychain;
- ошибки Яндекса и backend показывают корректное состояние UI.

UI-тесты с mock backend:

- экран входа открывается без сессии;
- успешный вход переводит в основной экран;
- ошибка входа оставляет пользователя на auth screen;
- logout возвращает на auth screen;
- при роли `user` не отображается будущий admin UI;
- при `403` показывается понятное сообщение.

Интеграционный тест с настоящим backend:

- получить OAuth token через SDK;
- обменять его на backend token;
- вызвать `GET /api/v1/me`;
- вызвать `GET /api/v1/trips`;
- перезапустить приложение и убедиться, что сессия восстановлена.

## Production checklist

Перед релизом нужно проверить:

- в Яндексе зарегистрирован правильный Bundle ID;
- используется правильный Team ID;
- production `Client ID` отличается от debug, если заведены разные приложения;
- backend доступен по HTTPS;
- `JWT_SECRET` и другие секреты настроены не дефолтными значениями;
- токены не пишутся в логи;
- iOS хранит backend-токены в Keychain;
- `UserDefaults` не содержит access/refresh token;
- logout инвалидирует refresh token на backend;
- ошибка `401` не приводит к бесконечному retry;
- права `admin/user` и `owner/editor/viewer` не определяются только на клиенте.
