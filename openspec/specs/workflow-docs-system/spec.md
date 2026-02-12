# workflow-docs-system Specification

## Purpose
Define project-owned operational documentation requirements for onboarding, execution, governance, and validation.
## Requirements
### Requirement: Project-Owned Workflow Documentation

The repository SHALL maintain operational documentation under `xxx_docs/` independent of upstream framework docs.

#### Scenario: New collaborator onboards from docs

- **WHEN** a collaborator reads `xxx_docs/`
- **THEN** they can set up the toolchain, run verify gates, and follow collaboration SOP without external assumptions

### Requirement: Brownfield Best Practices

Documentation SHALL include actionable brownfield guidance for change planning and risk control.

#### Scenario: Team starts a change in an existing codebase

- **WHEN** a collaborator follows brownfield onboarding guidance
- **THEN** they capture invariants, risk hotspots, and verify baselines before implementation

### Requirement: Usability Proof Record

Documentation SHALL include a concrete validation record for the demo app.

#### Scenario: Team validates workflow integrity

- **WHEN** local verification and appdemo tests are executed
- **THEN** results are captured in docs with commands and outcomes

### Requirement: Governance and Observability Runbooks

Project documentation SHALL include dedicated runbooks for memory governance and observability.

#### Scenario: Collaborator needs to operate phase 4/5 routines

- **WHEN** they read project docs
- **THEN** they can execute memory-safe session recording and metrics collection without external instructions

### Requirement: Plan Traceability Maintenance

Documentation SHALL keep an explicit mapping from plan phases to implementation artifacts.

#### Scenario: Team checks plan completion status

- **WHEN** they review traceability docs
- **THEN** each plan phase maps to concrete files, scripts, and command evidence

### Requirement: Doctor Runbook Coverage

Project docs SHALL include operation and interpretation guidance for workflow doctor output.

#### Scenario: Contributor runs diagnostics

- **WHEN** they execute the doctor command
- **THEN** documentation explains how to interpret failures and next actions

### Requirement: Metrics Interpretation Guidance

Project docs SHALL explain the meaning and use of advanced metrics indicators.

#### Scenario: Weekly review is performed

- **WHEN** team reviews generated metrics
- **THEN** documentation provides threshold guidance and tuning directions

### Requirement: Workflow Policy Configuration Documentation

Project docs SHALL explain workflow policy and threshold configuration.

#### Scenario: Team needs to tune governance strictness

- **WHEN** contributors update policy settings
- **THEN** docs describe configurable keys, defaults, and tradeoffs
- **AND** remediation steps are documented for failed checks

### Requirement: Strict Branch and Worktree Runbook

Project docs SHALL define strict branch naming, owner mapping, and linked worktree requirements.

#### Scenario: Collaborator prepares a new implementation branch

- **WHEN** they follow project docs
- **THEN** they can create a valid branch/worktree layout that passes policy gate
- **AND** docs include remediation for strict-fail conditions

