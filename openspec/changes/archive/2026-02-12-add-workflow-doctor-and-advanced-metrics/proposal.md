## Why

The kernel already has baseline metrics, but it lacks a one-command operational health check and does not yet fully report the six improvement indicators defined in the master plan. We need stronger observability and diagnostics to make this workflow project product-grade.

## What Changes

- Add `workflow doctor` command to validate runtime prerequisites, structure integrity, and process health.
- Extend metrics collector to output the six plan indicators:
  - lead time P50/P90
  - verify failure rate and top failure steps
  - rework counts from verify failures
  - parallel throughput
  - spec drift event count
  - token cost availability status
- Add generated doctor report to `xxx_docs/generated/`.
- Update runbooks with doctor/advanced-metrics operations.

## Capabilities

### New Capabilities

- `workflow-doctor`: one-command health diagnosis for this workflow kernel.
- `advanced-metrics-indicators`: weekly report with all core improvement indicators defined by the project plan.

### Modified Capabilities

- `workflow-observability`: extend from basic verify stats to full plan indicator set.
- `workflow-docs-system`: include doctor workflows and interpretation guidance.

## Impact

- Affected code: `scripts/collect-metrics.ps1`, `scripts/workflow-doctor.ps1`, `package.json`
- Affected docs: `xxx_docs/*`
- Affected specs: observability and docs capabilities
