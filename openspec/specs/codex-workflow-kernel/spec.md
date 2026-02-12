# codex-workflow-kernel Specification

## Purpose
TBD - created by archiving change bootstrap-codex-workflow-kernel. Update Purpose after archive.
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

