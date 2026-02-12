## ADDED Requirements

### Requirement: Governance Gate Health Check

Workflow doctor SHALL report policy-gate and indicator-gate health.

#### Scenario: Contributor runs doctor

- **WHEN** `npm run workflow:doctor` executes
- **THEN** doctor includes checks for workflow policy gate and indicator gate outcomes
- **AND** failed governance checks degrade overall doctor status

