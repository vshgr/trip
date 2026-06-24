# Анализ текущего iOS-приложения

Документ фиксирует состояние iOS-приложения перед интеграцией с backend.

## Структура iOS

- `Trip/TripApp.swift`: точка входа SwiftUI-приложения.
- `Trip/ContentView.swift`: основной экран и локальные stores.
- `Trip/Features/Trips/TripsViews.swift`: каталог поездок и редактор поездки.
- `Trip/Features/AppShell/TripWorkspaceViews.swift`: рабочая область выбранной поездки.
- `Trip/Features/Plan/PlanViews.swift`: календарь, план, timeline, редактор активностей.
- `Trip/Features/Expenses/ExpenseViews.swift`: расходы, участники, балансы и история.
- `Trip/Models.swift`: локальные модели, persistence в UserDefaults, расчеты расходов.
- `Trip/ItineraryData.swift`: встроенный маршрут Europe Trip.
- `TripWidget/TripWidget.swift`: WidgetKit extension, читает App Group cache.

## Основные локальные модели

- `TravelTrip`: поездка, даты, города, участники.
- `TripDay`: день маршрута.
- `PlanItem`: элемент плана.
- `ExpenseItem`: расход.
- `ExpenseCurrency`: валюта.

Backend не должен напрямую копировать SwiftUI-модели. Для интеграции лучше добавить отдельные API DTO, mapper и repository layer.

## Что относится к поездке

- название;
- даты;
- города;
- гостевые участники;
- дни маршрута;
- plan items;
- расходы;
- балансы;
- данные для виджета.

## Что относится к пользователю

Сейчас в iOS нет полноценной модели authenticated user. Backend добавляет:

- пользователя;
- сессии;
- системную роль `admin/user`;
- связь с Яндекс ID;
- membership в поездках.

## UserDefaults и App Group

iOS сейчас хранит данные локально:

- каталог поездок;
- дни поездки;
- расходы;
- курсы валют;
- данные виджета в App Group.

После интеграции backend должен стать источником истины, а UserDefaults/App Group должны остаться cache-слоем для быстрого открытия, offline-поведения и WidgetKit.

## Важные бизнес-правила из iOS

- Поездка требует непустое название и корректный диапазон дат.
- Участники расходов сейчас являются строками, а не пользователями.
- Plan item может быть exact-time, period или unscheduled.
- Расписание использует периоды: утро, день, вечер, ночь.
- Деньги в iOS сейчас считаются через `Double`, backend заменяет это на minor units.
- Балансы считаются отдельно по валютам.
- Widget читает локальный cache, поэтому iOS должен сохранять ответ `GET /api/v1/trips/{trip_id}/widget` в App Group.

## Рекомендация для интеграции

1. Сгенерировать или вручную создать DTO по Swagger.
2. Добавить `APIClient`.
3. Добавить `TokenStore`.
4. Добавить repository layer между ViewModel/Store и API.
5. Сначала подключить read endpoints.
6. Потом подключить create/update/delete.
7. Затем включить Яндекс ID и import локальных данных.
