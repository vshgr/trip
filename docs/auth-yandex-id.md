# Авторизация через Яндекс ID

Текущая iOS-реализация добавляет UI входа, регистрации и профиля. Backend уже умеет принимать OAuth token Яндекс ID через `POST /api/v1/auth/yandex`.

## Что уже есть

- Кнопка профиля на экране `Поездки`.
- Экран входа и регистрации через Яндекс ID.
- Локальный профиль пользователя в `UserDefaults`.
- Получение профиля по OAuth-токену через `GET https://login.yandex.ru/info` в локальном iOS flow.
- В debug-сборке без `YandexClientID` основная кнопка Яндекс ID создает preview-профиль, чтобы можно было проверить интерфейс без отдельной dev-кнопки.

## Что значит регистрация

Отдельной формы регистрации нет. Первый успешный вход через Яндекс ID должен создавать или находить пользователя Trip. Сейчас iOS умеет сделать это локально, а backend уже умеет сделать это серверно через `POST /api/v1/auth/yandex`.

Авторизация не блокирует приложение: поездки, планы, расходы и виджет остаются доступными без входа.

## Что нужно для реального входа

В Яндекс OAuth нужно зарегистрировать iOS-приложение и получить `Client ID`.

Для iOS LoginSDK потребуются:

- Swift Package: `https://github.com/yandexmobile/yandex-login-sdk-ios`.
- URL scheme: `yx{Client ID}`.
- `LSApplicationQueriesSchemes`: `primaryyandexloginsdk`, `secondaryyandexloginsdk`.
- Associated Domain: `applinks:yx{Client ID}.oauth.yandex.ru`.
- Значение `YandexClientID` в Info.plist или build settings.

Официальная документация Яндекс ID указывает LoginSDK для iOS и схему `yx{Client ID}`. GitHub-репозиторий SDK на 24 июня 2026 показывает более свежий release 3.1.1, чем версия 3.0.0 в навигации документации, поэтому при подключении SDK лучше зафиксировать конкретную стабильную версию после проверки в Xcode.

## Backend-flow, который нужно подключить в iOS

1. Получить OAuth-токен через Yandex LoginSDK.
2. Передать токен backend-у:

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

3. Backend валидирует токен через Яндекс ID.
4. Backend создает/обновляет пользователя Trip и возвращает backend-сессию.
5. iOS хранит `access_token`, `refresh_token` и профиль из backend response.
6. Сырой OAuth-токен Яндекса не хранится.
