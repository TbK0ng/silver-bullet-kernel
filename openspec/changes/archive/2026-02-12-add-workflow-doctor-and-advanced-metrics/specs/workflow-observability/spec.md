## ADDED Requirements

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
