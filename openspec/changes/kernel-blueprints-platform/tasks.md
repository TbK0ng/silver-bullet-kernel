## 1. Blueprint Contract and Schema

- [ ] 1.1 Define blueprint metadata schema and required baseline outputs.
- [ ] 1.2 Define command contract for list/apply/verify flows.

## 2. Runtime Implementation

- [ ] 2.1 Add blueprint command dispatcher under `sbk`.
- [ ] 2.2 Implement blueprint apply engine with template rendering and target safety checks.
- [ ] 2.3 Implement blueprint verify command with deterministic baseline checks.

## 3. Blueprint Packs

- [ ] 3.1 Add initial packs: `api-service`, `worker-service`, `cli-tool`, `monorepo-service`.
- [ ] 3.2 Add per-pack post-generation validation scripts.

## 4. Validation and Docs

- [ ] 4.1 Add e2e tests for apply/verify per blueprint archetype.
- [ ] 4.2 Document blueprint lifecycle, extension, and governance.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [ ] | `openspec/changes/kernel-blueprints-platform/*` | Define blueprint capability contract and acceptance scenarios. | `openspec validate kernel-blueprints-platform --type change --strict --json --no-interactive` | Pending |
| 2.1 | [ ] | `scripts/sbk.ps1`, `scripts/*blueprint*.ps1` | Add and route blueprint command surface. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1` | Pending |
| 3.1 | [ ] | `config/blueprints/**` | Add four initial blueprint packs and metadata. | `npx vitest run tests/e2e/*blueprint*.test.ts` | Pending |
| 4.2 | [ ] | `docs/**` | Add blueprint usage and governance runbook. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Pending |
