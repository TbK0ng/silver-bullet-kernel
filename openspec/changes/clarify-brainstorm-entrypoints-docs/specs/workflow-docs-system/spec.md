## MODIFIED Requirements

### Requirement: `sbk` Command Runbook Coverage
Project docs SHALL define `sbk` command usage and subcommand mapping with explicit trigger semantics.

#### Scenario: Contributor needs command reference
- **WHEN** they read command docs
- **THEN** they can map `sbk` subcommands to verify/policy/doctor/change/session workflows
- **AND** docs include troubleshooting guidance for adapter selection and overrides

#### Scenario: Contributor distinguishes explicit triggers from conditional stage execution
- **WHEN** contributor reads docs for `sbk flow run`, `sbk new-change`, and `sbk explore`
- **THEN** docs clearly identify which actions require explicit invocation
- **AND** docs clearly identify stage behavior that is conditional on flags/context
- **AND** docs avoid claiming implicit behavior for commands that do not auto-trigger that behavior

#### Scenario: Contributor identifies explicit high-risk switches
- **WHEN** contributor reads docs for `sbk flow run` and `sbk migrate-specs`
- **THEN** docs explicitly call out high-risk opt-in switches (`--force`, `--allow-beta`, `--unsafe-overwrite`)
- **AND** docs describe their trigger boundaries and expected impact

#### Scenario: Contributor needs script-evidence trigger baseline
- **WHEN** contributor needs to verify trigger semantics against runtime implementation
- **THEN** docs provide a dedicated trigger matrix page with script path/line evidence
- **AND** the page distinguishes explicit triggers, conditional triggers, and non-triggers

#### Scenario: Contributor needs repo-local command equivalents
- **WHEN** contributor follows runbook examples in this repository
- **THEN** docs provide repo-local equivalents for `sbk` command usage
- **AND** examples make clear when `npm run sbk -- ...` should be used

### Requirement: Feature Selection and Prompt Playbook Coverage
Practice guides SHALL provide operator-facing decision support for similar SBK capabilities and Codex-oriented prompt templates without conflating AI delegation with command semantics.

#### Scenario: Contributor executes workflow via Codex
- **WHEN** contributor asks Codex to run SBK workflows
- **THEN** docs provide reusable prompt templates mapped to concrete stages
- **AND** templates include expected outputs and success checks
- **AND** templates distinguish "AI executes explicit steps" from "command implicit behavior"
