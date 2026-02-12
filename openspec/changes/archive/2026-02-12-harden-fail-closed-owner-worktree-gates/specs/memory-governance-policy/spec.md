## ADDED Requirements

### Requirement: Owner-Scoped Session Evidence

Memory governance SHALL enforce that session evidence aligns with the branch owner identity.

#### Scenario: Implementation branch owner is `alice`

- **WHEN** policy gate inspects session evidence paths
- **THEN** evidence must be under `.trellis/workspace/alice/`
- **AND** non-owner session paths do not satisfy the enforcement check

