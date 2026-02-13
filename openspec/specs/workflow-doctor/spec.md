# workflow-doctor Specification

## Purpose
Define one-command workflow health diagnostics for runtime, structure, and process readiness.
## Requirements
### Requirement: Workflow Health Diagnosis

The project SHALL provide a one-command workflow health diagnosis.

#### Scenario: Contributor runs doctor command

- **WHEN** `npm run workflow:doctor` is executed
- **THEN** it checks runtime prerequisites and workflow structure integrity
- **AND** outputs both markdown and JSON reports under `docs/generated/`

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

