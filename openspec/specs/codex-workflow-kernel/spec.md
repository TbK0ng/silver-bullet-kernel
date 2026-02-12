# codex-workflow-kernel Specification

## Purpose
Define the core Codex-first workflow behavior, verification gates, and collaboration invariants for this repository.
## Requirements
### Requirement: Codex-First Runtime Contract

The repository SHALL provide a Codex-first workflow while retaining Claude Code compatibility.

#### Scenario: Codex runtime bootstraps with project policies

- **WHEN** a developer starts work in Codex
- **THEN** Codex can load project skills and instructions from repository-managed files
- **AND** policy files define verify gates and change-control expectations

### Requirement: Deterministic Verification Gates

The repository SHALL provide deterministic verify entry points and enforce them in CI.

#### Scenario: Developer runs local fast gate

- **WHEN** the developer executes `npm run verify:fast`
- **THEN** lint and typecheck run
- **AND** the command exits non-zero if any check fails

#### Scenario: CI runs full verification

- **WHEN** CI executes `npm run verify:ci`
- **THEN** lint, typecheck, tests, e2e, build, and OpenSpec strict validation run
- **AND** merge is blocked on failure

### Requirement: Parallel Collaboration Policy

The repository SHALL define a worktree policy for two-person collaboration.

#### Scenario: Two collaborators execute in parallel

- **WHEN** collaborators work on separate changes
- **THEN** each change uses isolated ownership and worktree boundaries
- **AND** spec merges occur through archive flow, not direct concurrent edits to canonical specs

### Requirement: Constitutional Guardrails

The kernel SHALL define and maintain constitution-level rules governing quality, source-of-truth ownership, and recoverability.

#### Scenario: Process change proposal is introduced

- **WHEN** contributors modify workflow behavior
- **THEN** changes are checked against constitutional rules before adoption

### Requirement: Metrics-Backed Improvement Loop

The kernel SHALL support data-driven process tuning.

#### Scenario: Weekly process review

- **WHEN** team reviews workflow performance
- **THEN** they use generated metrics artifacts to identify failures and throughput bottlenecks
- **AND** they update policy or scripts based on measured evidence

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

