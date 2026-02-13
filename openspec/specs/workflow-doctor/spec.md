# workflow-doctor Specification

## Purpose
Define one-command workflow health diagnostics for runtime, structure, and process readiness.
## Requirements
### Requirement: Workflow Health Diagnosis

The workflow doctor SHALL produce machine-readable and human-readable diagnostics.

#### Scenario: Run workflow doctor

- **WHEN** contributor executes `npm run workflow:doctor`
- **THEN** doctor validates required runtime/tooling/workflow checks
- **AND** outputs both markdown and JSON reports under `.metrics/`
- **AND** exits non-zero when any required check is unhealthy

### Requirement: Actionable Check Results

Doctor output SHALL provide actionable pass/fail signals.

#### Scenario: A required dependency or directory is missing

- **WHEN** doctor detects a failed check
- **THEN** the report records the failed check with remediation guidance
- **AND** summary clearly marks overall status as degraded

### Requirement: Governance Gate Health Check

Workflow doctor SHALL report policy-gate and indicator-gate health.

#### Scenario: Contributor runs doctor

- **WHEN** `npm run workflow:doctor` executes
- **THEN** doctor includes checks for workflow policy gate and indicator gate outcomes
- **AND** failed governance checks degrade overall doctor status

