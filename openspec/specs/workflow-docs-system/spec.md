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

#### Scenario: Contributor resolves repeated verify failures

- **WHEN** they run verify loop command
- **THEN** docs describe loop controls, diagnostics artifacts, and escalation steps
- **AND** docs include deterministic semantic rename runbook for refactor-class changes

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

#### Scenario: Team tunes active-change task evidence schema

- **WHEN** contributors update policy settings
- **THEN** docs describe required task evidence columns and failure remediations
- **AND** examples show compliant `tasks.md` table structure

### Requirement: Strict Branch and Worktree Runbook

Project docs SHALL define strict branch naming, owner mapping, and linked worktree requirements.

#### Scenario: Collaborator prepares a new implementation branch

- **WHEN** they follow project docs
- **THEN** they can create a valid branch/worktree layout that passes policy gate
- **AND** docs include remediation for strict-fail conditions

### Requirement: Security Policy Runbook Coverage

Project docs SHALL include operational guidance for security policy gate behavior.

#### Scenario: Contributor triggers security policy failure

- **WHEN** policy gate reports sensitive path or secret-pattern violation
- **THEN** docs explain failure interpretation, redaction workflow, and remediation
- **AND** docs reference policy-as-code keys used by the gate

### Requirement: Progressive Disclosure Memory Runbook Coverage

Project docs SHALL include staged memory retrieval and audit usage guidance.

#### Scenario: Contributor needs minimal context injection

- **WHEN** they use memory context tooling
- **THEN** docs explain index/detail stages, ID-based retrieval, and audit outputs
- **AND** docs provide Codex skill usage best practices

