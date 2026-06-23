CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
    id UUID PRIMARY KEY,
    email CITEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    password_hash TEXT NULL,
    avatar_url TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ NULL,
    device_id TEXT NULL,
    device_name TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE trips (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users(id),
    client_id UUID NULL,
    title TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    timezone TEXT NULL,
    cover_image_url TEXT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ NULL,
    CONSTRAINT trips_date_range_check CHECK (end_date >= start_date)
);

CREATE TABLE trip_cities (
    id UUID PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sort_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    UNIQUE (trip_id, sort_order)
);

CREATE TABLE trip_members (
    id UUID PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    joined_at TIMESTAMPTZ NOT NULL,
    UNIQUE (trip_id, user_id),
    CONSTRAINT trip_members_role_check CHECK (role IN ('owner', 'editor', 'viewer'))
);

CREATE TABLE trip_parties (
    id UUID PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    display_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE trip_invitations (
    id UUID PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    role TEXT NOT NULL,
    invited_email CITEXT NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ NULL,
    revoked_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT trip_invitations_role_check CHECK (role IN ('editor', 'viewer'))
);

CREATE TABLE trip_days (
    id UUID PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    client_id UUID NULL,
    local_id TEXT NULL,
    date DATE NOT NULL,
    city_id UUID NULL REFERENCES trip_cities(id) ON DELETE SET NULL,
    city_name_snapshot TEXT NULL,
    sort_order INTEGER NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    UNIQUE (trip_id, date)
);

CREATE TABLE plan_items (
    id UUID PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    client_id UUID NULL,
    source_day_id UUID NOT NULL REFERENCES trip_days(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    city_id UUID NULL REFERENCES trip_cities(id) ON DELETE SET NULL,
    city_name_snapshot TEXT NULL,
    category TEXT NOT NULL,
    schedule_type TEXT NOT NULL,
    period TEXT NULL,
    start_at TIMESTAMPTZ NULL,
    end_at TIMESTAMPTZ NULL,
    timezone TEXT NULL,
    sort_index INTEGER NOT NULL,
    needs_ticket BOOLEAN NOT NULL DEFAULT FALSE,
    ticket_bought BOOLEAN NOT NULL DEFAULT FALSE,
    version BIGINT NOT NULL DEFAULT 1,
    created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ NULL,
    CONSTRAINT plan_items_category_check CHECK (category IN ('transfer', 'rest', 'walk', 'sight', 'food', 'shopping')),
    CONSTRAINT plan_items_schedule_type_check CHECK (schedule_type IN ('exact', 'period', 'unscheduled')),
    CONSTRAINT plan_items_period_check CHECK (period IS NULL OR period IN ('morning', 'afternoon', 'evening', 'night')),
    CONSTRAINT plan_items_ticket_check CHECK (needs_ticket OR NOT ticket_bought),
    CONSTRAINT plan_items_exact_check CHECK (schedule_type <> 'exact' OR (start_at IS NOT NULL AND timezone IS NOT NULL)),
    CONSTRAINT plan_items_end_after_start_check CHECK (end_at IS NULL OR start_at IS NULL OR end_at > start_at)
);

CREATE TABLE expenses (
    id UUID PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    client_id UUID NULL,
    title TEXT NOT NULL,
    amount_minor BIGINT NOT NULL,
    currency_code CHAR(3) NOT NULL,
    paid_by_party_id UUID NOT NULL REFERENCES trip_parties(id),
    occurred_at TIMESTAMPTZ NOT NULL,
    category TEXT NULL,
    note TEXT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ NULL,
    CONSTRAINT expenses_amount_positive_check CHECK (amount_minor > 0),
    CONSTRAINT expenses_currency_check CHECK (currency_code IN ('RUB', 'EUR', 'USD', 'KZT', 'JPY'))
);

CREATE TABLE expense_shares (
    id UUID PRIMARY KEY,
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    party_id UUID NOT NULL REFERENCES trip_parties(id),
    share_minor BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT expense_shares_share_nonnegative_check CHECK (share_minor >= 0)
);

CREATE TABLE receipts (
    id UUID PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    uploaded_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    status TEXT NOT NULL,
    image_url TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT receipts_status_check CHECK (status IN ('uploaded', 'processing', 'failed', 'ready', 'converted'))
);

CREATE TABLE receipt_items (
    id UUID PRIMARY KEY,
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount_minor BIGINT NULL,
    currency_code CHAR(3) NULL,
    assigned_party_id UUID NULL REFERENCES trip_parties(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT receipt_items_currency_check CHECK (currency_code IS NULL OR currency_code IN ('RUB', 'EUR', 'USD', 'KZT', 'JPY'))
);
