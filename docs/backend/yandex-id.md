# План подключения Яндекс ID

## Целевая схема

1. Пользователь нажимает “Войти через Яндекс” в iOS.
2. iOS открывает Yandex LoginSDK.
3. SDK возвращает OAuth token.
4. iOS отправляет token на backend:

```http
POST /api/v1/auth/yandex
```

```json
{
  "oauth_token": "token-from-yandex-login-sdk",
  "device_id": "ios-device-id",
  "device_name": "iPhone"
}
```

5. Backend запрашивает профиль пользователя у Яндекса.
6. Backend создает или находит локального пользователя.
7. Backend связывает пользователя с Яндекс ID в `user_identity_providers`.
8. Backend возвращает свои `access_token` и `refresh_token`.
9. iOS использует `Authorization: Bearer <access_token>`.

## Что нужно сделать в Яндексе

1. Создать OAuth-приложение.
2. Добавить iOS platform.
3. Указать Bundle ID и Team ID.
4. Включить доступ к email и базовому профилю.
5. Скопировать Client ID для iOS.

Официальные страницы:

- регистрация приложения: `https://yandex.ru/dev/id/doc/ru/register-client`
- iOS LoginSDK: `https://yandex.ru/dev/id/doc/ru/mobileauthsdk/ios/sdk-ios-main`
- получение информации о пользователе: `https://yandex.ru/dev/id/doc/ru/user-information`

## Что нужно сделать в iOS

1. Подключить Yandex LoginSDK.
2. Сконфигурировать SDK через Client ID.
3. Получить OAuth token после успешного входа.
4. Отправить token на `POST /api/v1/auth/yandex`.
5. Сохранить backend `access_token` и `refresh_token`.
6. При `401 TOKEN_EXPIRED` вызывать `POST /api/v1/auth/refresh`.

## Что уже есть на backend

- Endpoint `POST /api/v1/auth/yandex`.
- Проверка token через `https://login.yandex.ru/info?format=json`.
- Создание пользователя, если его еще нет.
- Связка Яндекс-аккаунта через `user_identity_providers`.
- Выдача backend tokens.

## Что добавить перед production

- Обязательную авторизацию для write endpoints.
- Проверку membership-прав на каждую поездку.
- Настройку HTTPS и production `JWT_SECRET`.
- Логи без персональных токенов.
