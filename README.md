# Trip

Trip is a SwiftUI iOS app for planning trips, tracking a day-by-day itinerary, and keeping travel expenses in one place. The project also includes a WidgetKit extension that shows the next city and the nearest planned activity for the Europe trip.

## Features

### Trip catalog

- Shows all saved trips on the main screen.
- Includes a predefined Europe Trip for July 3-21, 2026.
- Supports creating, editing, and deleting custom trips.
- Stores trip title, date range, cities, and participants.
- Shows per-trip summary cards with date range, route, participant count, plan progress, and expense totals.

### Day-by-day planning

- Displays a calendar-style overview for the selected trip.
- Uses city colors to make route changes easy to scan.
- Shows how full each day is as an occupancy percentage.
- Lets the user switch a day's city from the available trip cities.
- Opens a detailed timeline for the selected day.

### Timeline editor

- Shows planned items on an hourly day grid.
- Supports scheduled items with start/end dates and times.
- Supports unscheduled period-based items such as morning, day, evening, and night.
- Handles activities that continue across midnight or span multiple days.
- Lets the user add, edit, delete, reorder, and reschedule plan items.
- Supports drag-and-drop between timeline hours and unscheduled sections.
- Tracks item categories: transfer, rest, walk, sight, food, and shopping.
- Tracks ticket requirements and whether tickets are already bought.
- Normalizes time input such as `930`, `9:30`, and `09.30`.

### Europe trip status

- Shows a dedicated status widget inside the app for the predefined Europe route.
- Highlights the next city, days until arrival, the next planned day, and the nearest activity.
- Uses the route data from the editable itinerary so changes are reflected in the status.

### Expenses

- Lets the user add expenses per trip.
- Supports participant-specific expenses.
- Supports RUB, EUR, USD, GBP, and TRY.
- Shows totals by currency.
- Calculates an approximate RUB total when exchange rates are available.
- Caches expenses and exchange rates locally.
- Fetches exchange rates from the Central Bank of Russia XML feed.
- Supports filtering expenses by participant.
- Lets the user delete individual expenses.

### Widget

- Includes a WidgetKit extension named `TripWidget`.
- Supports small and medium widget families.
- Shows the next city, days until it, route progress, and the next plan item.
- Refreshes periodically and reads shared Europe Trip data through the app group `group.com.alisa.trip`.

### Persistence

- Stores trips, itinerary edits, expenses, and cached rates in `UserDefaults`.
- Stores the Europe Trip itinerary in shared app group defaults for the widget.
- Migrates older saved itinerary data where possible.
- Falls back to bundled itinerary data when no saved state exists.

## Project Structure

- `Trip/TripApp.swift` - app entry point.
- `Trip/ContentView.swift` - SwiftUI screens and UI components.
- `Trip/Models.swift` - models, stores, persistence, scheduling logic, expense logic, and exchange-rate parsing.
- `Trip/ItineraryData.swift` - bundled Europe Trip route and default day data.
- `TripWidget/TripWidget.swift` - WidgetKit timeline provider, widget views, and widget status logic.
- `Trip.xcodeproj` - Xcode project.
- `scripts/codex-publish-mr.sh` - helper script for publishing Codex changes through a new branch and PR.

## Requirements

- Xcode with iOS SDK support.
- iOS target with SwiftUI and WidgetKit.
- App Group capability configured for `group.com.alisa.trip` if the widget should read live app data.

## Running

1. Open `Trip.xcodeproj` in Xcode.
2. Select the `Trip` scheme.
3. Choose an iOS simulator or device.
4. Build and run.

For widget testing, run the app at least once so it can write shared itinerary data, then add the `Europe Trip` widget on the simulator or device.

## Git Workflow

The default branch is `main`.

Future Codex updates should be made in separate branches named `codex/<description>`. When publishing a merge request, use:

```bash
scripts/codex-publish-mr.sh "short change description"
```

