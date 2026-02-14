## Why

`sbk migrate-specs --apply` currently writes delta spec content to canonical spec files with full overwrite semantics. This can erase existing canonical requirements that are not present in the delta file, causing specification loss and governance drift.

## What Changes

- Change `scripts/openspec-migrate-specs.ps1` default apply behavior from overwrite to merge.
- Implement requirement/scenario-aware delta merge logic for `ADDED`, `MODIFIED`, `REMOVED`, and `RENAMED` sections.
- Add an explicit opt-in `--unsafe-overwrite` mode for exceptional cases requiring full replacement.
- Add e2e regression coverage for non-destructive migration behavior.
- Update docs to clarify merge-by-default behavior and overwrite risk.

## Capabilities

### Modified Capabilities
- `codex-workflow-kernel`: enforce non-destructive canonical spec migration behavior when using `sbk migrate-specs --apply`.

## Impact

- Affected code: `scripts/openspec-migrate-specs.ps1`, `scripts/sbk.ps1`, `tests/e2e/openspec-migrate-specs.e2e.test.ts`, `docs/02-功能手册-命令原理与产物.md`, `docs/06-多项目类型接入与配置指南.md`.
- Operational impact: canonical specs are preserved by default during migration; destructive behavior now requires explicit user intent.
