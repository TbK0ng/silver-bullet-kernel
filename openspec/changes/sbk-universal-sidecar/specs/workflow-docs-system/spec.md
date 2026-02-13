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
