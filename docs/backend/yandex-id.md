# Yandex ID

## Current Backend Flow

The backend exposes:

```text
POST /api/v1/auth/yandex
```

Request:

```json
{
  "oauth_token": "token-from-yandex-login-sdk",
  "device_id": "ios-device-id",
  "device_name": "iPhone"
}
```

The backend calls Yandex ID user info API, finds or creates a local user, links the Yandex account in `user_identity_providers`, and returns the same response shape as local login:

```json
{
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "token_type": "Bearer",
    "expires_at": "...",
    "user": {}
  }
}
```

## What Is Needed In Yandex

1. Register an app in Yandex OAuth.
2. Choose an app type intended for user authorization.
3. Add the iOS platform and the exact iOS App ID: Apple Team ID plus Bundle ID.
4. Enable Yandex ID permissions needed by the app:
   - email;
   - profile/login/name;
   - avatar, optional.
5. Copy the Client ID.

Official docs:

- Registration: https://yandex.ru/dev/id/doc/ru/register-client
- iOS LoginSDK: https://yandex.ru/dev/id/doc/ru/mobileauthsdk/ios/sdk-ios-main
- User info endpoint: https://yandex.ru/dev/id/doc/ru/user-information

## What Is Needed In iOS

1. Add Yandex LoginSDK.
2. Configure it with the Yandex OAuth Client ID.
3. On successful login, get the Yandex OAuth token from the SDK.
4. Send that token to `POST /api/v1/auth/yandex`.
5. Store the backend `access_token` and `refresh_token`.
6. Use `Authorization: Bearer <access_token>` for authenticated backend calls.

## What Is Needed On Backend Deployment

Backend does not need the Yandex client secret for this mobile-token flow. It verifies the token by requesting:

```text
GET https://login.yandex.ru/info?format=json
Authorization: OAuth <oauth_token>
```

The server must have outbound HTTPS access to `login.yandex.ru` and a valid system CA bundle.
