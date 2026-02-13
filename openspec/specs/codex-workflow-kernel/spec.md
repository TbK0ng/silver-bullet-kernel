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

#### Scenario: Contributor runs bounded verify/fix loop

- **WHEN** contributor executes `npm run verify:loop`
- **THEN** loop performs bounded verify attempts with diagnostics after failed attempts
- **AND** command exits non-zero when attempts are exhausted

#### Scenario: Contributor runs local verify with virtualenv artifacts present

- **WHEN** `npm run verify:fast` or `npm run verify` is executed in a repo containing `.venv/`
- **THEN** lint scope excludes virtualenv/runtime vendor artifacts
- **AND** verify outcome reflects project files only

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

#### Scenario: Active change tasks evidence table is decorative only

- **WHEN** policy gate validates active change artifacts
- **THEN** `tasks.md` must contain a canonical `Task Evidence` table with required
  columns (`Files`, `Action`, `Verify`, `Done`)
- **AND** the table must include at least one non-empty data row
- **AND** verify fails when schema or row-level evidence is missing

### Requirement: CI Branch Governance Fail-Closed

The kernel SHALL fail CI policy checks when branch-delta governance context is unavailable or degenerate.

#### Scenario: CI base ref resolves to current HEAD

- **WHEN** `verify:ci` runs policy gate in PR governance flow
- **AND** configured base ref resolves to the same commit as `HEAD`
- **THEN** policy gate fails as invalid branch-delta context
- **AND** remediation instructs operators to provide an event-correct base ref

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

### Requirement: Tool-Deterministic Refactor Path

The kernel SHALL provide a semantic refactor path for TypeScript symbol rename operations.

#### Scenario: Contributor performs symbol rename

- **WHEN** contributor executes semantic rename command with file/line/column and new symbol name
- **THEN** rename is resolved by TypeScript compiler APIs (not plain text replace)
- **AND** command fails with explicit error when symbol resolution is invalid

### Requirement: Task Granularity Policy Enforcement

The kernel SHALL enforce bounded task granularity for active-change evidence rows.

#### Scenario: Task evidence row is oversized

- **WHEN** policy gate parses active change task-evidence rows
- **THEN** each row is checked against configured bounds (files count/action length)
- **AND** verify fails with remediation when bounds are exceeded

### Requirement: Orchestrator Boundary Governance

The kernel SHALL enforce thin orchestrator boundaries as policy-as-code.

#### Scenario: Dispatcher agent exposes write-capable tools

- **WHEN** policy gate validates orchestrator contracts
- **THEN** dispatcher toolset is checked against forbidden tool rules
- **AND** verify fails if forbidden tools are present

### Requirement: Indicator Gate Entry Point Consistency

The kernel SHALL expose a stable indicator-gate command contract for operators.

#### Scenario: Contributor executes workflow indicator gate command

- **WHEN** contributor runs `npm run workflow:gate`
- **THEN** command executes indicator-threshold checks (not policy gate checks)
- **AND** docs and npm script mapping stay consistent with this behavior

