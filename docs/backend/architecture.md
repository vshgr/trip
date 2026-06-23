# Backend Architecture

## C4 Context

```mermaid
C4Context
    title Trip Backend Context
    Person(user, "Traveler", "Plans trips and expenses on iOS")
    System(ios, "Trip iOS App", "SwiftUI app with local cache")
    System(widget, "Trip Widget", "WidgetKit extension reading App Group cache")
    System(api, "Trip Backend", "Go modular monolith")
    SystemDb(db, "PostgreSQL", "Source of truth")
    Rel(user, ios, "Uses")
    Rel(ios, api, "Syncs via HTTPS JSON")
    Rel(api, db, "Reads/writes")
    Rel(ios, widget, "Writes App Group cache")
```

## C4 Container

```mermaid
flowchart LR
    ios["iOS App"]
    api["HTTP API"]
    identity["Identity"]
    trips["Trips"]
    itinerary["Itinerary"]
    expenses["Expenses"]
    widgets["Widgets Read Model"]
    receipts["Receipts"]
    db[("PostgreSQL")]

    ios --> api
    api --> identity
    api --> trips
    api --> itinerary
    api --> expenses
    api --> widgets
    api --> receipts
    identity --> db
    trips --> db
    itinerary --> db
    expenses --> db
    widgets --> db
    receipts --> db
```

## Components

- `internal/platform`: config, database, logging, auth, clock, HTTP helpers.
- `internal/identity`: users, sessions, tokens.
- `internal/trips`: trips, cities, members, invitations, parties, access policy.
- `internal/itinerary`: days, plan items, schedule validation, occupancy.
- `internal/expenses`: money, expense shares, balances, simplified transfers.
- `internal/widgets`: aggregate read-only widget data.
- `internal/receipts`: receipt upload/processing model prepared for later OCR.

## Dependency Rules

- HTTP handlers call application use cases.
- Application layer manages transactions.
- Domain packages contain business rules and have no HTTP/SQL dependencies.
- Repository packages implement storage details.
- API DTOs do not become domain entities.

## Transactions

Transactions are required for trip creation, date-range changes, invitations, ownership transfer, expense/share changes, reorder operations, local imports, and receipt-to-expense conversion.

## Security Model

- User authentication uses short-lived JWT access tokens and hashed refresh tokens.
- Authorization is centralized through trip policies.
- Unknown or unauthorized foreign resources should generally return 404.
- Passwords, refresh tokens, access tokens, invitation tokens, and receipt contents are never logged.

## Offline Strategy

The backend becomes the source of truth, but the iOS app keeps UserDefaults/App Group cache for fast open, temporary offline use, WidgetKit, and gradual migration.
