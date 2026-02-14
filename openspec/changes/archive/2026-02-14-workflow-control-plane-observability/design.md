## Context

Current workflow metrics and diagnostics are repository-local. Product-grade operation requires fleet visibility, consistent rollout channels, and channel-aware policy enforcement to avoid uncontrolled upgrades.

## Goals / Non-Goals

**Goals**
- Aggregate workflow health data across repositories.
- Provide fleet-level command surface for status and drift detection.
- Introduce stable/beta channel model for kernel and blueprint updates.
- Enforce compatibility policy for channel rollout.

**Non-Goals**
- Implement hosted dashboard service in first iteration.
- Force all repositories onto the same channel.
- Replace repository-local metrics artifacts.

## Decisions

### Decision 1: Fleet command family
Add:
- `sbk fleet collect --roots <path-list>`
- `sbk fleet report --format <md|json>`
- `sbk fleet doctor`

### Decision 2: Channel-aware release manifest
Define release manifest with:
- version
- channel
- compatibility constraints
- migration notes

### Decision 3: Channel policy gate
Add gate checks to prevent invalid channel jumps or incompatible updates.

### Decision 4: Layered observability
Keep repo-local metrics as source artifacts and aggregate into fleet snapshots.

## Risks / Trade-offs

- [Risk] Fleet collection can be expensive on many repos.
  - Mitigation: incremental collection and caching.
- [Risk] Channel governance may slow urgent fixes.
  - Mitigation: emergency override with audited justification.

## Migration Plan

1. Define fleet metrics schema and collection contract.
2. Implement fleet command family.
3. Add release manifest and channel policy checks.
4. Document rollout playbook for stable/beta channels.
