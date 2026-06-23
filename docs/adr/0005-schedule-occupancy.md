# ADR 0005: Schedule Occupancy

## Status

Accepted

## Decision

Backend schedule occupancy unions overlapping exact-time intervals before calculating occupied minutes.

## Context

The current iOS client sums intervals clipped to 08:00-23:00 and may double-count overlapping activities. Backend should preserve the concept of schedule occupancy while making the calculation mathematically correct.

## Consequences

- Occupancy remains distinct from completion.
- `schedule_occupancy_percent` is calculated from exact-time activities only.
- `completion_percent` is reserved for a future task-completion feature.
