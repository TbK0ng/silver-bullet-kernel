## 1. Runtime Behavior Fix

- [x] 1.1 Replace overwrite-based apply logic in `openspec-migrate-specs.ps1` with merge-by-default behavior.
- [x] 1.2 Add explicit `--unsafe-overwrite` path and wire CLI argument mapping from `sbk`.

## 2. Regression Coverage

- [x] 2.1 Add e2e tests for non-destructive merge behavior and idempotent re-apply.
- [x] 2.2 Add e2e failure-case coverage for missing requirement targets under `MODIFIED`.

## 3. Docs and Artifact Sync

- [x] 3.1 Update user docs describing `migrate-specs` behavior and unsafe overwrite option.
- [x] 3.2 Keep OpenSpec change artifacts complete and strict-validated.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `scripts/openspec-migrate-specs.ps1` | Implement requirement/scenario-aware merge engine and switch default apply semantics to merge. | `npm run test:e2e -- tests/e2e/openspec-migrate-specs.e2e.test.ts` | Canonical requirements are preserved while delta intent is merged in. |
| 1.2 | [x] | `scripts/sbk.ps1` | Expose `--unsafe-overwrite` in help and token mapping for migrate-specs dispatcher. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1` | CLI usage includes unsafe mode with explicit opt-in semantics. |
| 2.1 | [x] | `tests/e2e/openspec-migrate-specs.e2e.test.ts` | Add pass-case coverage for merge behavior and idempotent second apply. | `npm run test:e2e -- tests/e2e/openspec-migrate-specs.e2e.test.ts` | Running apply twice yields stable canonical content. |
| 2.2 | [x] | `tests/e2e/openspec-migrate-specs.e2e.test.ts` | Add failure-case coverage for MODIFIED requirement missing in canonical spec. | `npm run test:e2e -- tests/e2e/openspec-migrate-specs.e2e.test.ts` | Migration fails closed instead of silently dropping intent. |
| 3.1 | [x] | `docs/02-功能手册-命令原理与产物.md`, `docs/06-多项目类型接入与配置指南.md` | Document merge-by-default behavior and unsafe overwrite flag. | `rg -n \"unsafe-overwrite|merge\" docs/02-功能手册-命令原理与产物.md docs/06-多项目类型接入与配置指南.md` | Runbooks now reflect safe default migration semantics. |
| 3.2 | [x] | `openspec/changes/fix-migrate-specs-merge/*` | Maintain complete proposal/design/tasks/spec delta chain and run strict validation. | `openspec validate --all --strict --no-interactive` | OpenSpec artifacts and implementation stay traceable. |
