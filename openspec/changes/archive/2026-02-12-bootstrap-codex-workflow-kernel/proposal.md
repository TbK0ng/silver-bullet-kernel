## Why

The workflow currently exists only as research notes and lacks an executable Codex-first reference implementation. We need a concrete repository that proves Trellis + OpenSpec can run as a brownfield-ready, two-person workflow with objective quality gates.

## What Changes

- Bootstrap a production-style repository using Trellis (execution policy) and OpenSpec (change artifacts).
- Implement verification entry points (`verify:fast`, `verify`, `verify:ci`) and CI enforcement.
- Add an `appdemo` service with tests as usability proof.
- Create project-owned docs under `xxx_docs/` for onboarding, operations, best practices, and troubleshooting.
- Define collaboration and worktree policy for two collaborators.

## Capabilities

### New Capabilities

- `codex-workflow-kernel`: Codex-first engineering workflow integrating Trellis and OpenSpec with enforceable quality gates.
- `appdemo-task-api`: A testable demo API used to prove workflow completeness and correctness.
- `workflow-docs-system`: Project-level documentation system in `xxx_docs/` covering setup, SOP, and best practices.

### Modified Capabilities

- None.

## Impact

- Affected code: `src/`, `tests/`, `scripts/`, `.github/workflows/`, `.trellis/spec/guides/`, `AGENTS.md`, `CLAUDE.md`
- Affected systems: Local developer workflow, CI pipeline, OpenSpec change lifecycle.
- Dependencies: Node.js runtime, OpenSpec CLI in CI for strict artifact validation.
