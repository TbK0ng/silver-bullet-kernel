## MODIFIED Requirements

### Requirement: Workflow Doctor Health Report

The workflow doctor SHALL produce machine-readable and human-readable diagnostics.

#### Scenario: Run workflow doctor

- **WHEN** contributor executes `npm run workflow:doctor`
- **THEN** doctor validates required runtime/tooling/workflow checks
- **AND** outputs both markdown and JSON reports under `.metrics/`
- **AND** exits non-zero when any required check is unhealthy
