## ADDED Requirements

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
