## MODIFIED Requirements

### Requirement: Retention and Redaction Policy

The workflow SHALL enforce retention boundaries and sensitive-data redaction.

#### Scenario: Durable artifact contains secret-like token

- **WHEN** policy gate inspects changed durable artifacts
- **THEN** secret-pattern scan runs against configured paths
- **AND** verify fails when redaction rules are violated

## ADDED Requirements

### Requirement: Progressive Disclosure Retrieval Contract

Memory governance SHALL provide staged retrieval (index first, details on demand).

#### Scenario: Agent requests memory context for a change

- **WHEN** memory context tool runs in `index` stage
- **THEN** it returns compact source descriptors with stable IDs
- **AND** detailed content is only returned in explicit `detail` stage by selected IDs

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
