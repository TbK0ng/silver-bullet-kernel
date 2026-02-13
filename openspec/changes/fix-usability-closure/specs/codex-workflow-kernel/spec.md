## MODIFIED Requirements

### Requirement: Deterministic Verification Gates

The repository SHALL provide deterministic verify entry points and enforce them in CI.

#### Scenario: Contributor runs bounded verify/fix loop

- **WHEN** contributor executes `npm run verify:loop`
- **THEN** loop performs bounded verify attempts with diagnostics after failed attempts
- **AND** command exits non-zero when attempts are exhausted

#### Scenario: Contributor runs local verify with virtualenv artifacts present

- **WHEN** `npm run verify:fast` or `npm run verify` is executed in a repo containing `.venv/`
- **THEN** lint scope excludes virtualenv/runtime vendor artifacts
- **AND** verify outcome reflects project files only

### Requirement: CI Branch Governance Fail-Closed

The kernel SHALL fail CI policy checks when branch-delta governance context is unavailable or degenerate.

#### Scenario: CI base ref resolves to current HEAD

- **WHEN** `verify:ci` runs policy gate in PR governance flow
- **AND** configured base ref resolves to the same commit as `HEAD`
- **THEN** policy gate fails as invalid branch-delta context
- **AND** remediation instructs operators to provide an event-correct base ref

## ADDED Requirements

### Requirement: Indicator Gate Entry Point Consistency

The kernel SHALL expose a stable indicator-gate command contract for operators.

#### Scenario: Contributor executes workflow indicator gate command

- **WHEN** contributor runs `npm run workflow:gate`
- **THEN** command executes indicator-threshold checks (not policy gate checks)
- **AND** docs and npm script mapping stay consistent with this behavior
