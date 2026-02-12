## ADDED Requirements

### Requirement: Enforced Change-Control Gate

The kernel SHALL block verification when implementation changes are not traceable to OpenSpec change artifacts.

#### Scenario: Implementation files change without OpenSpec change mapping

- **WHEN** verify commands execute on non-trivial implementation changes
- **THEN** policy gate fails if no corresponding change artifacts are present
- **AND** remediation guidance points contributor to create or complete a change package

### Requirement: Active Change Artifact Completeness

The kernel SHALL require complete active-change artifacts before verify succeeds.

#### Scenario: Active change exists but required artifacts are missing

- **WHEN** policy gate evaluates active changes
- **THEN** each active change must include proposal, design, tasks, and spec deltas
- **AND** verify fails if artifact completeness is not met

