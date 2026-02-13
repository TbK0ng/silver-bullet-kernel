## MODIFIED Requirements

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
