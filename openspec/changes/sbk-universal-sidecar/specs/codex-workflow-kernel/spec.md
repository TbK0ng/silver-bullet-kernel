## ADDED Requirements

### Requirement: Runtime Contract Includes `sbk` Entry Command
The repository SHALL provide a canonical `sbk` command as the preferred workflow entrypoint.

#### Scenario: Team bootstraps a new project
- **WHEN** contributors configure SBK in a new repository
- **THEN** they can execute core lifecycle actions via `sbk` command aliases without invoking individual scripts manually
- **AND** command behavior remains traceable to policy-as-code configuration

### Requirement: Verify/Policy Uses Target-Aware Adapter Context
The kernel SHALL resolve implementation scope and verify steps from adapter/runtime configuration.

#### Scenario: Supported ecosystem uses adapter command matrix
- **WHEN** verify commands execute under an active adapter
- **THEN** the command matrix for `fast`/`full`/`ci` is read from adapter config
- **AND** policy gate uses adapter-provided implementation path matching rules
