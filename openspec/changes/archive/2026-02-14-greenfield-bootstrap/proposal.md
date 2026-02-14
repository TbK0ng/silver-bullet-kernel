## Why

SBK already supports adapter-aware verification and policy gates for existing repositories, but it still assumes a brownfield starting point. Contributors who want to start from zero need a deterministic way to scaffold project-level planning artifacts and minimal adapter-aligned language skeletons before implementation begins.

## What Changes

- Add a dedicated `sbk greenfield` command to scaffold project-level workflow artifacts for 0-to-1 repositories.
- Add a deterministic bootstrap script that creates `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `CONTEXT.md`, and `.planning/research/.gitkeep`.
- Add adapter-aware language starter stubs for `node-ts`, `python`, `go`, `java`, and `rust`.
- Keep scaffolding idempotent by default and require explicit force to overwrite existing files.
- Add e2e coverage for command routing, artifact generation, and idempotent behavior.
- Update runbooks to include greenfield-first onboarding path.

## Capabilities

### Modified Capabilities
- `codex-workflow-kernel`: extend runtime entry contract with explicit greenfield scaffold command and artifact generation behavior.

## Impact

- Affected code: `scripts/sbk.ps1`, new `scripts/greenfield-bootstrap.ps1`, `tests/e2e/*.test.ts`, and docs updates in `docs/02-*`, `docs/05-*`, `docs/06-*`.
- Operational impact: teams can bootstrap SBK in new repos with deterministic artifacts and adapter-aligned starter files before first implementation change.
