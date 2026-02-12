# workflow-observability Specification

## Purpose
Define telemetry and metrics reporting requirements for continuous workflow improvement.
## Requirements
### Requirement: Verify Run Telemetry

The workflow SHALL record telemetry for each verify entry point.

#### Scenario: Verify command executes

- **WHEN** `verify:fast`, `verify`, or `verify:ci` is executed
- **THEN** a run record is persisted with mode, duration, status, and step-level outcomes

### Requirement: Weekly Metrics Reporting

The workflow SHALL provide a command that generates weekly operational metrics from telemetry.

#### Scenario: Team runs metrics collection

- **WHEN** `npm run metrics:collect` executes
- **THEN** it generates a markdown summary and JSON snapshot under `xxx_docs/generated/`
- **AND** report includes success rate, per-mode durations, and failure-step trends

### Requirement: Full Plan Indicator Coverage

Workflow observability SHALL report the six improvement indicators defined by the project plan.

#### Scenario: Team generates weekly report

- **WHEN** `npm run metrics:collect` executes
- **THEN** output includes:
  - lead time P50/P90
  - verify failure rate and top failure steps
  - rework count
  - parallel throughput indicators
  - spec drift event count
  - token cost availability status

### Requirement: Lead Time and Drift Estimation

Observability SHALL include reproducible estimation logic for lead time and spec drift.

#### Scenario: Team reviews process trends

- **WHEN** they inspect generated metrics artifacts
- **THEN** they can see lead-time quantiles and drift event counts with explicit method notes

