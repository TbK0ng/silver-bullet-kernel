## ADDED Requirements

### Requirement: CI Branch Governance Fail-Closed

The kernel SHALL fail CI policy checks when branch-delta governance context is unavailable.

#### Scenario: CI cannot resolve base branch for delta checks

- **WHEN** `verify:ci` runs policy gate
- **THEN** missing or unresolved base ref causes policy failure
- **AND** CI does not degrade this condition to warning

### Requirement: Owner/Change Branch Mapping Enforcement

The kernel SHALL enforce branch naming and ownership mapping for implementation changes.

#### Scenario: Implementation branch name does not match required pattern

- **WHEN** implementation edits are present
- **THEN** policy gate validates branch pattern with owner and change identifiers
- **AND** fails when pattern or active-change mapping is invalid

### Requirement: Linked Worktree Requirement for Local Implementation

The kernel SHALL enforce linked worktree usage for local implementation changes.

#### Scenario: Contributor edits implementation on main worktree

- **WHEN** local policy gate detects implementation edits
- **THEN** it fails if current git directory is not a linked worktree
- **AND** remediation points to creating/using per-change worktree

