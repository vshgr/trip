# ADR 0001: Modular Monolith

## Status

Accepted

## Decision

Build the backend as a Go modular monolith.

## Context

The product is early, the domain is tightly coupled, and the team is small. Microservices would add deployment and data-consistency complexity without clear benefit.

## Consequences

- One deployable API process.
- One PostgreSQL database.
- Internal module boundaries are kept so modules can be split later if the product requires it.
