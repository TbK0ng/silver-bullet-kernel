# memory-governance-policy Specification

## Purpose
Define enforceable memory source, retention, and redaction rules for workflow artifacts.
## Requirements
### Requirement: Memory Source Governance

The workflow SHALL explicitly define approved memory sources and their responsibilities.

#### Scenario: Agent determines what context to inject

- **WHEN** an agent starts or resumes work
- **THEN** it references approved sources (`.trellis/workspace/`, `openspec/`, `docs/`)
- **AND** it avoids ad-hoc undocumented context stores

### Requirement: Retention and Redaction Policy

The workflow SHALL enforce retention boundaries and sensitive-data redaction.

#### Scenario: Durable artifact contains secret-like token

- **WHEN** policy gate inspects changed durable artifacts
- **THEN** secret-pattern scan runs against configured paths
- **AND** verify fails when redaction rules are violated

### Requirement: Session Evidence for Implemented Changes

Memory governance SHALL require session evidence artifacts for implementation changes.

#### Scenario: CI validates implementation branch delta

- **WHEN** implementation files are changed in branch delta
- **THEN** policy gate requires corresponding session evidence updates under `.trellis/workspace/`
- **AND** CI fails when session evidence is missing

### Requirement: Owner-Scoped Session Evidence

Memory governance SHALL enforce that session evidence aligns with the branch owner identity.

#### Scenario: Implementation branch owner is `alice`

- **WHEN** policy gate inspects session evidence paths
- **THEN** evidence must be under `.trellis/workspace/alice/`
- **AND** non-owner session paths do not satisfy the enforcement check

### Requirement: Progressive Disclosure Retrieval Contract

Memory governance SHALL provide staged retrieval (index first, details on demand).

#### Scenario: Agent requests memory context for a change

- **WHEN** memory context tool runs in `index` stage
- **THEN** it returns compact source descriptors with stable IDs
- **AND** detailed content is only returned in explicit `detail` stage by selected IDs

#### Scenario: Agent requests memory context from non-`sbk-*` branch

- **WHEN** current branch does not provide owner/change identity
- **THEN** retrieval gracefully falls back to requested change or auto-detected active change
- **AND** command does not fail due empty branch-derived change id

### Requirement: Memory Retrieval Audit Trail

Memory governance SHALL keep auditable records of memory retrieval actions.

#### Scenario: Memory context tool is executed

- **WHEN** index or detail stage completes
- **THEN** audit metadata is appended to local metrics artifacts
- **AND** records include stage, selected IDs, and source counts

### Requirement: Session Evidence Disclosure Metadata

Memory governance SHALL require disclosure metadata in owner-scoped session evidence.

#### Scenario: Implementation branch includes owner workspace updates

- **WHEN** policy gate validates owner-scoped session evidence files
- **THEN** required disclosure metadata fields are present
- **AND** verify fails if disclosure metadata is missing

