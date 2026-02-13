## 1. OpenSpec and Contract Baseline

- [x] 1.1 Define greenfield scaffold capability scope in proposal, design, and spec delta.

## 2. Runtime Implementation

- [x] 2.1 Add `sbk greenfield` command routing and argument mapping.
- [x] 2.2 Implement deterministic greenfield bootstrap script with project-level artifacts and adapter stubs.
- [x] 2.3 Ensure bootstrap behavior is idempotent by default and supports explicit overwrite mode.

## 3. Regression Coverage

- [x] 3.1 Add e2e tests for greenfield artifact generation and adapter stub output.
- [x] 3.2 Add e2e tests for idempotent rerun behavior and force overwrite path.

## 4. Documentation and Evidence

- [x] 4.1 Update docs/runbooks for greenfield-first onboarding with `sbk greenfield`.
- [x] 4.2 Complete task evidence rows with commands and outcomes.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/greenfield-bootstrap/proposal.md`, `openspec/changes/greenfield-bootstrap/design.md`, `openspec/changes/greenfield-bootstrap/tasks.md`, `openspec/changes/greenfield-bootstrap/specs/codex-workflow-kernel/spec.md` | Captured greenfield scaffold capability scope, runtime contract, and acceptance scenarios. | `openspec validate greenfield-bootstrap --type change --strict --json --no-interactive` | Strict change validation passes with no issues. |
| 2.1 | [x] | `scripts/sbk.ps1` | Added `greenfield` subcommand routing, help text, and argument forwarding contract. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1` | `sbk` help output includes `greenfield` with full option contract. |
| 2.2 | [x] | `scripts/greenfield-bootstrap.ps1` | Implemented deterministic project-level artifact generation and adapter-aware starter stub scaffolding. | `npx vitest run tests/e2e/sbk-greenfield-bootstrap.e2e.test.ts` | E2E validates artifact generation across adapter scenarios. |
| 2.3 | [x] | `scripts/greenfield-bootstrap.ps1` | Implemented idempotent default behavior and explicit `--force` overwrite mode. | `npx vitest run tests/e2e/sbk-greenfield-bootstrap.e2e.test.ts` | E2E confirms rerun preserves files by default and overwrites with force. |
| 3.1 | [x] | `tests/e2e/sbk-greenfield-bootstrap.e2e.test.ts` | Added pass-case coverage for artifact generation and config adapter update. | `npx vitest run tests/e2e/sbk-greenfield-bootstrap.e2e.test.ts` | New test suite covers 4 greenfield bootstrap scenarios and passes. |
| 3.2 | [x] | `tests/e2e/sbk-greenfield-bootstrap.e2e.test.ts` | Added rerun and force-overwrite regression coverage with no-language-stubs mode. | `npx vitest run tests/e2e/sbk-greenfield-bootstrap.e2e.test.ts` | Idempotent and force overwrite contracts are locked by regression tests. |
| 4.1 | [x] | `docs/02-功能手册-命令原理与产物.md`, `docs/05-命令与产物速查表.md`, `docs/06-多项目类型接入与配置指南.md` | Updated runbooks for greenfield-first onboarding and command quick references. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Docs sync gate passes after command and runtime contract updates. |
| 4.2 | [x] | `openspec/changes/greenfield-bootstrap/tasks.md` | Finalized evidence rows with real command outcomes and completion state. | `openspec validate --all --strict --no-interactive` | All specs and changes validate strictly (11 passed, 0 failed). |
