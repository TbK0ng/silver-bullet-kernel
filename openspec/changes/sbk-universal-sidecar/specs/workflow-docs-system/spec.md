## ADDED Requirements

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
