## Why

Single-repo metrics are useful but insufficient for platform-grade operations. To support many repositories and teams, SBK needs a control-plane style observability and release-governance layer with cross-repo aggregation, health dashboards, and stable/beta rollout channels.

## What Changes

- Add cross-repo metrics aggregation and trend analysis workflow.
- Add `sbk fleet` command family for multi-repo health checks and reporting.
- Add release channel contract (`stable`, `beta`) for kernel and blueprint distribution.
- Add policy checks for channel compatibility and rollout safety.

## Capabilities

### New Capabilities
- `workflow-control-plane`: multi-repo observability and fleet health orchestration.
- `kernel-release-channels`: managed channel-based rollout for SBK assets.

### Modified Capabilities
- `workflow-observability`: extend from single-repo snapshots to fleet-level indicators.

## Impact

- Affected code: metrics scripts, release metadata, docs, and command entrypoints.
- Operational impact: SBK can be managed as a platform across many repositories with safer rollout discipline.
