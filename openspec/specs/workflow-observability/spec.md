# workflow-observability Specification

## Purpose
Define telemetry and metrics reporting requirements for continuous workflow improvement.
## Requirements
### Requirement: Verify Run Telemetry

The workflow SHALL record telemetry for each verify entry point.

#### Scenario: Verify loop command executes

- **WHEN** `npm run verify:loop` is executed
- **THEN** loop attempts and outcomes are persisted as machine-readable local artifacts
- **AND** each failed attempt records diagnostics command results for postmortem analysis

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

### Requirement: Indicator Threshold Gate

Workflow observability SHALL enforce threshold-based governance checks from generated metrics.

#### Scenario: Team runs indicator gate

- **WHEN** `npm run workflow:gate` executes
- **THEN** metrics snapshot is evaluated against configured thresholds
- **AND** failing thresholds return actionable non-zero results

### Requirement: Configurable Governance Thresholds

Threshold behavior SHALL be managed as repository configuration.

#### Scenario: Team tunes process targets

- **WHEN** contributors update workflow-policy config
- **THEN** threshold values and severities are reviewable in version control
- **AND** subsequent gate runs use updated config values

