## MODIFIED Requirements

### Requirement: Weekly Metrics Report Generation

The workflow observability system SHALL produce weekly metrics summaries from verify telemetry.

#### Scenario: Generate weekly metrics report

- **WHEN** `npm run metrics:collect` executes successfully
- **THEN** it generates a markdown summary and JSON snapshot under `.metrics/`
- **AND** outputs include lead-time percentiles, rework count, parallel throughput, and spec-drift indicators
- **AND** token-cost status is included from `.metrics/token-cost.json` when present
