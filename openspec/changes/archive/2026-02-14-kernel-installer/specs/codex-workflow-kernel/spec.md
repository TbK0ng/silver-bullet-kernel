## ADDED Requirements

### Requirement: Kernel Install and Upgrade Entry Commands
The kernel SHALL provide explicit install and upgrade commands for target repositories.

#### Scenario: Contributor installs SBK into external repository
- **WHEN** contributor runs `sbk install --target-repo-root <path> --preset <minimal|full>`
- **THEN** command copies kernel files according to preset scope
- **AND** command reports created/skipped/overwritten counts

#### Scenario: Contributor upgrades existing SBK installation
- **WHEN** contributor runs `sbk upgrade --target-repo-root <path> --preset <minimal|full>`
- **THEN** installer runs in overwrite mode
- **AND** command reports overwritten file count explicitly

### Requirement: Preset-Based Install Surface
The kernel SHALL support deterministic preset scopes for distribution.

#### Scenario: Minimal preset install
- **WHEN** contributor selects `minimal` preset
- **THEN** target receives strict governance core files required for verify/policy/doctor entrypoints
- **AND** volatile runtime artifacts are excluded

#### Scenario: Full preset install
- **WHEN** contributor selects `full` preset
- **THEN** target receives extended runtime assets, configs, docs, and workflow specs
- **AND** install still excludes runtime state directories

### Requirement: Non-Destructive Script Injection
The kernel SHALL inject package scripts additively when target package metadata exists.

#### Scenario: Target repository contains package.json
- **WHEN** installer runs against target with package metadata
- **THEN** missing SBK scripts are added only when corresponding files exist
- **AND** existing script definitions are preserved unless overwrite mode updates file content only
