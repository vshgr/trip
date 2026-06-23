# ADR 0004: Offline Sync

## Status

Accepted

## Decision

Use optimistic concurrency and idempotent client IDs for the first sync version.

## Context

The iOS app is local-first today. A full CRDT-based sync engine is too large for the first backend iteration.

## Consequences

- Mutable entities have `version`.
- Clients send `expected_version`.
- Creates may include `client_id`.
- Conflicts return HTTP 409 `VERSION_CONFLICT`.
