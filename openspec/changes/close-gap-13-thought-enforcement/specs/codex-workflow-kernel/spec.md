## MODIFIED Requirements

### Requirement: CI Branch Governance Fail-Closed

The kernel SHALL fail CI policy checks when branch-delta governance context is unavailable or degenerate.

#### Scenario: CI base ref resolves to current HEAD

- **WHEN** `verify:ci` runs policy gate
- **AND** configured base ref resolves to the same commit as `HEAD`
- **THEN** policy gate fails as invalid branch-delta context
- **AND** remediation instructs operators to provide an event-correct base ref

### Requirement: Active Change Artifact Completeness

The kernel SHALL require complete active-change artifacts before verify succeeds.

#### Scenario: Active change tasks miss evidence schema

- **WHEN** policy gate validates active change artifacts
- **THEN** `tasks.md` must include evidence columns `Files`, `Action`, `Verify`, and `Done`
- **AND** verify fails if required evidence columns are missing

### Requirement: Deterministic Verification Gates

The repository SHALL provide deterministic verify entry points and enforce them in CI.

#### Scenario: Contributor runs bounded verify/fix loop

- **WHEN** contributor executes `npm run verify:loop`
- **THEN** loop performs bounded verify attempts with diagnostics after failed attempts
- **AND** command exits non-zero when attempts are exhausted

### Requirement: Tool-Deterministic Refactor Path

The kernel SHALL provide a semantic refactor path for TypeScript symbol rename operations.

#### Scenario: Contributor performs symbol rename

- **WHEN** contributor executes semantic rename command with file/line/column and new symbol name
- **THEN** rename is resolved by TypeScript compiler APIs (not plain text replace)
- **AND** command fails with explicit error when symbol resolution is invalid

