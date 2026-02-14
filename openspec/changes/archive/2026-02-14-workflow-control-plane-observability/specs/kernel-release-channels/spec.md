## ADDED Requirements

### Requirement: Channel-Based Kernel Rollout Contract
The workflow SHALL define stable and beta rollout channels for kernel-distributed assets.

#### Scenario: Contributor requests beta channel update
- **WHEN** contributor applies a beta channel kernel update
- **THEN** release manifest compatibility is validated before applying changes
- **AND** rollout metadata is recorded in audit artifacts

### Requirement: Channel Safety Policy Gate
The workflow SHALL block unsafe channel transitions.

#### Scenario: Incompatible channel transition detected
- **WHEN** policy gate detects unsupported transition (for example beta to incompatible stable major)
- **THEN** verification fails with remediation steps
- **AND** upgrade is blocked until compatibility conditions are satisfied
