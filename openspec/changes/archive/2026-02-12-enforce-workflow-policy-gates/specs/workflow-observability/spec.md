## ADDED Requirements

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

