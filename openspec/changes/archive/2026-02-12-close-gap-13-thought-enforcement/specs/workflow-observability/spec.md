## MODIFIED Requirements

### Requirement: Verify Run Telemetry

The workflow SHALL record telemetry for each verify entry point.

#### Scenario: Verify loop command executes

- **WHEN** `npm run verify:loop` is executed
- **THEN** loop attempts and outcomes are persisted as machine-readable local artifacts
- **AND** each failed attempt records diagnostics command results for postmortem analysis

