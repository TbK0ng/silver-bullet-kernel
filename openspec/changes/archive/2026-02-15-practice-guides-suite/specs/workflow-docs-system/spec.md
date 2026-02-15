## ADDED Requirements

### Requirement: Practice Guide Suite Under `docs/practice`
Project documentation SHALL provide a dedicated practice-guide suite under `docs/practice/` that covers onboarding and execution from SBK import to full workflow takeover.

#### Scenario: Contributor needs end-to-end onboarding path
- **WHEN** a contributor starts from a repository that has just introduced SBK
- **THEN** `docs/practice/` provides a sequenced guide from initial setup to first successful run
- **AND** the guide includes both greenfield and brownfield execution paths

#### Scenario: Contributor needs command-level operational detail
- **WHEN** a contributor follows any practice guide in `docs/practice/`
- **THEN** the document provides executable manual commands for user-operated steps
- **AND** it distinguishes commands that can be delegated to AI from commands that must be run manually

### Requirement: Feature Selection and Prompt Playbook Coverage
Practice guides SHALL provide operator-facing decision support for similar SBK capabilities and Codex-oriented prompt templates.

#### Scenario: Contributor must choose between similar commands
- **WHEN** a contributor compares overlapping capabilities (for example `flow` vs manual chaining, `install` vs `upgrade`, `verify` variants)
- **THEN** documentation explains when to use each option
- **AND** documentation includes trade-offs and recommended combinations

#### Scenario: Contributor executes workflow via Codex
- **WHEN** contributor asks Codex to run SBK workflows
- **THEN** docs provide reusable prompt templates mapped to concrete stages
- **AND** templates include expected outputs and success checks
