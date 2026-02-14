## ADDED Requirements

### Requirement: Deep Intake Analysis Command
The workflow SHALL provide a deep brownfield intake analysis command before strict governance rollout.

#### Scenario: Contributor runs intake analysis on legacy repository
- **WHEN** contributor runs `sbk intake analyze --target-repo-root <path>`
- **THEN** command generates architecture and risk artifacts under `.metrics/`
- **AND** output includes explicit scoring dimensions and rationale

### Requirement: Staged Hardening Plan Generation
The workflow SHALL generate a staged hardening plan from intake outputs.

#### Scenario: Intake plan derives governance progression
- **WHEN** contributor runs `sbk intake plan --target-repo-root <path>`
- **THEN** command outputs phased backlog for `lite`, `balanced`, and `strict` progression
- **AND** each phase includes entry criteria and verification commands

### Requirement: Readiness Verification for Strict Mode
Strict-mode rollout SHALL require explicit readiness verification from intake artifacts.

#### Scenario: Intake verify detects unmet strict prerequisites
- **WHEN** contributor runs `sbk intake verify --target-repo-root <path>`
- **THEN** command fails when critical prerequisites are not met
- **AND** remediation guidance references missing artifacts and thresholds
