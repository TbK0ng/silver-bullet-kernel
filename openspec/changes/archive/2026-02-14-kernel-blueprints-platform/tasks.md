## 1. Blueprint Contract and Schema

- [x] 1.1 Define blueprint metadata schema and required baseline outputs.
- [x] 1.2 Define command contract for list/apply/verify flows.

## 2. Runtime Implementation

- [x] 2.1 Add blueprint command dispatcher under `sbk`.
- [x] 2.2 Implement blueprint apply engine with template rendering and target safety checks.
- [x] 2.3 Implement blueprint verify command with deterministic baseline checks.

## 3. Blueprint Packs

- [x] 3.1 Add initial packs: `api-service`, `worker-service`, `cli-tool`, `monorepo-service`.
- [x] 3.2 Add per-pack post-generation validation scripts.

## 4. Validation and Docs

- [x] 4.1 Add e2e tests for apply/verify per blueprint archetype.
- [x] 4.2 Document blueprint lifecycle, extension, and governance.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/kernel-blueprints-platform/*` | Define blueprint capability contract and acceptance scenarios. | `openspec validate kernel-blueprints-platform --type change --strict --json --no-interactive` | Completed (2026-02-13) |
| 2.1 | [x] | `scripts/sbk.ps1`, `scripts/sbk-blueprint.ps1`, `scripts/common/sbk-runtime.ps1` | Add and route blueprint command surface with deterministic apply/verify execution. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1 blueprint list` | Completed (2026-02-13) |
| 3.1 | [x] | `config/blueprints/registry.json`, `config/blueprints/packs/**` | Add four initial blueprint packs, versioned metadata, and post-apply validators. | `npx vitest run tests/e2e/sbk-blueprint.e2e.test.ts` | Completed (2026-02-13) |
| 4.2 | [x] | `tests/e2e/sbk-blueprint.e2e.test.ts`, `docs/06-多项目类型接入与配置指南.md` | Add blueprint flow e2e coverage and operator-facing usage guidance. | `npx vitest run tests/e2e/sbk-blueprint.e2e.test.ts` | Completed (2026-02-13) |
