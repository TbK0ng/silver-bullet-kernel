# workflow-docs-system Specification

## Purpose
Define project-owned operational documentation requirements for onboarding, execution, governance, and validation.
## Requirements
### Requirement: Project-Owned Workflow Documentation

The repository SHALL maintain operational documentation under `docs/` independent of upstream framework docs.

#### Scenario: New collaborator onboards from docs

- **WHEN** a collaborator reads `docs/`
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

### Requirement: Multi-Project Onboarding Coverage
Project docs SHALL include a runbook for attaching SBK to new repositories across supported ecosystems.

#### Scenario: Contributor onboards SBK into a non-TS project
- **WHEN** they follow the onboarding documentation
- **THEN** they can configure adapter/profile/command entrypoint for the target project
- **AND** they can run first-pass verification with deterministic outcomes

### Requirement: `sbk` Command Runbook Coverage
Project docs SHALL define `sbk` command usage and subcommand mapping.

#### Scenario: Contributor needs command reference
- **WHEN** they read command docs
- **THEN** they can map `sbk` subcommands to verify/policy/doctor/change/session workflows
- **AND** docs include troubleshooting guidance for adapter selection and overrides

### Requirement: Platform Parity Documentation Coverage
Project docs SHALL describe capability parity boundaries between Claude and Codex with executable alternatives.

#### Scenario: Contributor needs parity expectations
- **WHEN** they consult onboarding/config docs
- **THEN** they can see which features are fully symmetric and which are manual-mode alternatives
- **AND** docs include how to inspect matrix using `sbk capabilities`

### Requirement: Embedded Trellis Spec References Stay Complete
Project SHALL include required Trellis guideline/spec documents referenced by workflow commands and skills.

#### Scenario: Contributor uses test-improvement or platform-thinking workflows
- **WHEN** contributor follows `improve-ut`, backend integration, or cross-platform command guidance
- **THEN** referenced files under `.trellis/spec/unit-test`, `.trellis/spec/backend`, and `.trellis/spec/guides` exist
- **AND** index documents include links to those guides for discoverability

