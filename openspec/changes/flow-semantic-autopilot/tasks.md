## 1. OpenSpec and Contract Baseline

- [x] 1.1 Capture orchestration and semantic-completeness requirements in proposal/design/spec deltas.

## 2. Runtime Orchestration

- [x] 2.1 Add `sbk flow` command routing and help contracts.
- [x] 2.2 Implement `sbk flow run` with decision-mode `auto|ask` and end-to-end stage execution.
- [x] 2.3 Emit deterministic flow summary artifacts under `.metrics/`.

## 3. Semantic Operation Completion

- [x] 3.1 Enable `reference-map` and `safe-delete-candidates` operations in runtime command surface.
- [x] 3.2 Add deterministic backend execution for Go/Java/Rust semantic rename and analysis operations.
- [x] 3.3 Update adapter capability metadata and validation checks for complete semantic contracts.

## 4. Governance Defaults and Docs

- [x] 4.1 Enable strict intake readiness requirement by default in workflow policy.
- [x] 4.2 Update command docs and quick-reference tables for new orchestration and semantic behaviors.

## 5. Regression Coverage

- [x] 5.1 Add/adjust e2e tests for flow orchestration decision paths.
- [x] 5.2 Add/adjust e2e tests for enabled semantic operations and non-TS adapters.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/flow-semantic-autopilot/proposal.md`, `openspec/changes/flow-semantic-autopilot/design.md`, `openspec/changes/flow-semantic-autopilot/specs/codex-workflow-kernel/spec.md`, `openspec/changes/flow-semantic-autopilot/specs/semantic-tooling-multi-language/spec.md` | Define orchestration + semantic-completion contract and acceptance scenarios. | `openspec validate flow-semantic-autopilot --type change --strict --no-interactive` | Implemented; strict change validation passed. |
| 2.1 | [x] | `scripts/sbk.ps1` | Add top-level `flow` route and help documentation for one-command execution. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1` | Implemented; command surface exposes `flow` route and help. |
| 2.2 | [x] | `scripts/sbk-flow.ps1` | Implement flow runner and key decision node controls (`auto|ask`). | `npx vitest run tests/e2e/sbk-flow.e2e.test.ts` | Implemented; e2e flow decision path coverage passed. |
| 2.3 | [x] | `scripts/sbk-flow.ps1` | Emit deterministic flow report artifacts for auditability. | `npx vitest run tests/e2e/sbk-flow.e2e.test.ts` | Implemented; report artifacts validated in flow e2e coverage. |
| 3.1 | [x] | `scripts/sbk-semantic.ps1`, `scripts/semantic-rename.ts`, `scripts/semantic-python.py` | Enable and route reference-map/safe-delete operations. | `npx vitest run tests/e2e/sbk-adapter-semantic.e2e.test.ts` | Implemented; reference-map and safe-delete-candidates now enabled and tested. |
| 3.2 | [x] | `scripts/sbk-semantic.ps1`, `scripts/semantic-index.py` | Add deterministic semantic backend for Go/Java/Rust operations. | `npx vitest run tests/e2e/sbk-adapter-semantic.e2e.test.ts` | Implemented; deterministic symbol-index backend validated for Go/Java/Rust. |
| 3.3 | [x] | `config/adapters/*.json`, `scripts/sbk-adapter.ps1` | Align capability metadata and validator requirements with complete semantic contract. | `npx vitest run tests/e2e/sbk-adapter-semantic.e2e.test.ts` | Implemented; adapter contract checks enforce full semantic capability fields. |
| 4.1 | [x] | `workflow-policy.json` | Set strict intake readiness requirement default to enabled. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1 -Mode local -NoReport -Quiet` | Implemented; strict readiness default enabled in policy. |
| 4.2 | [x] | `docs/02-功能手册-命令原理与产物.md`, `docs/05-命令与产物速查表.md`, `docs/06-多项目类型接入与配置指南.md` | Document one-command flow and enabled semantic operations for onboarding users. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Implemented; docs sync gate passed with updated command guides. |
| 5.1 | [x] | `tests/e2e/sbk-flow.e2e.test.ts` | Add flow orchestration regression coverage for decision resolution and stage outputs. | `npx vitest run tests/e2e/sbk-flow.e2e.test.ts` | Implemented; new e2e test covers flow orchestration branches. |
| 5.2 | [x] | `tests/e2e/sbk-adapter-semantic.e2e.test.ts` | Add regression coverage for enabled semantic operations and Go/Java/Rust support. | `npx vitest run tests/e2e/sbk-adapter-semantic.e2e.test.ts` | Implemented; semantic operation regressions covered across adapters. |
