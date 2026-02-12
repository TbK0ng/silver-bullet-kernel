## ADDED Requirements

### Requirement: Deterministic CI Telemetry Source

Workflow observability SHALL support deterministic telemetry source selection for CI.

#### Scenario: CI verifies indicator thresholds

- **WHEN** `verify:ci` runs metrics collection and indicator gate
- **THEN** telemetry input path is isolated from local historical metrics
- **AND** threshold evaluation is reproducible across CI runs
