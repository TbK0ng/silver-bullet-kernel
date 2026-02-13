## ADDED Requirements

### Requirement: Adapter SDK Plugin Lifecycle
The workflow SHALL support plugin-style adapter lifecycle management.

#### Scenario: Contributor validates and registers adapter plugin
- **WHEN** contributor runs `sbk adapter validate --path <adapter-pack>` followed by `sbk adapter register --path <adapter-pack>`
- **THEN** adapter pack is schema-validated and added to adapter registry
- **AND** strict profile refuses unvalidated adapters

### Requirement: Adapter Diagnostics Command
The workflow SHALL provide adapter diagnostics for active target repositories.

#### Scenario: Contributor runs adapter doctor
- **WHEN** contributor runs `sbk adapter doctor --target-repo-root <path>`
- **THEN** command reports active adapter, validation status, and missing capabilities
- **AND** remediation guidance is included for failed checks
