# ADR 0003: Money Storage

## Status

Accepted

## Decision

Store money as integer minor units and ISO currency code.

## Context

The iOS app currently uses `Double`, but backend balance and split calculations must not lose cents/kopecks.

## Consequences

- Use `amount_minor BIGINT`.
- Use deterministic remainder allocation for equal splits.
- Keep balances separate per currency.
- Support the current iOS currency set first: RUB, EUR, USD, KZT, JPY.
