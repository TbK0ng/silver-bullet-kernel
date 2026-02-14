## ADDED Requirements

### Requirement: One-Command Orchestration Flow
The workflow SHALL provide a one-command orchestration entry that executes end-to-end onboarding/hardening stages.

#### Scenario: Contributor runs flow in auto mode
- **WHEN** contributor runs `sbk flow run --decision-mode auto`
- **THEN** runtime resolves key decision nodes deterministically
- **AND** executes the selected stage chain without manual command chaining
- **AND** writes a structured flow report artifact under `.metrics/`

### Requirement: Decision-Node Control Mode
The orchestration flow SHALL support deterministic auto decisions and interactive operator decisions.

#### Scenario: Contributor runs flow in ask mode
- **WHEN** contributor runs `sbk flow run --decision-mode ask`
- **THEN** unresolved key nodes are presented to operator prompts
- **AND** selected decisions are captured in flow report output
- **AND** flow continues with chosen values

### Requirement: Strict Intake Readiness Default
Strict profile governance SHALL enforce intake readiness artifacts by default.

#### Scenario: Strict verify runs without intake readiness
- **WHEN** strict profile policy gate executes and readiness artifact is missing
- **THEN** policy gate fails with remediation
- **AND** contributor is instructed to run intake analyze/plan/verify stages