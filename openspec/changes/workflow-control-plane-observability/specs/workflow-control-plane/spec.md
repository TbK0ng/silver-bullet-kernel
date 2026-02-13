## ADDED Requirements

### Requirement: Fleet-Level Workflow Collection
The workflow SHALL support cross-repository health collection and aggregation.

#### Scenario: Contributor collects fleet metrics
- **WHEN** contributor runs `sbk fleet collect --roots <path-list>`
- **THEN** command ingests per-repo workflow metrics and produces aggregate snapshot artifacts
- **AND** each record includes repository identity and collection timestamp

### Requirement: Fleet Health Reporting
The workflow SHALL provide fleet-level trend and risk reporting.

#### Scenario: Contributor runs fleet report
- **WHEN** contributor runs `sbk fleet report --format md`
- **THEN** command outputs consolidated indicators (lead time, failure rate, rework, drift, token cost availability)
- **AND** report highlights repositories exceeding thresholds
