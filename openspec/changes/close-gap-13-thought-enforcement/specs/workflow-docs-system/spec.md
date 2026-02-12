## MODIFIED Requirements

### Requirement: Workflow Policy Configuration Documentation

Project docs SHALL explain workflow policy and threshold configuration.

#### Scenario: Team tunes active-change task evidence schema

- **WHEN** contributors update policy settings
- **THEN** docs describe required task evidence columns and failure remediations
- **AND** examples show compliant `tasks.md` table structure

### Requirement: Governance and Observability Runbooks

Project documentation SHALL include dedicated runbooks for memory governance and observability.

#### Scenario: Contributor resolves repeated verify failures

- **WHEN** they run verify loop command
- **THEN** docs describe loop controls, diagnostics artifacts, and escalation steps
- **AND** docs include deterministic semantic rename runbook for refactor-class changes

