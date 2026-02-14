## 1. Adapter SDK Contract

- [x] 1.1 Define adapter SDK schema and registry contract.
- [x] 1.2 Define strict-mode activation rules for plugin adapters.

## 2. Adapter Command Runtime

- [x] 2.1 Add `sbk adapter list/register/validate/doctor` commands.
- [x] 2.2 Implement adapter plugin validation and registry write flow.

## 3. Semantic Tooling Expansion

- [x] 3.1 Define cross-language semantic operation API.
- [x] 3.2 Implement backend integrations for Python/Go/Java/Rust capabilities.
- [x] 3.3 Add deterministic reporting and audit outputs for semantic operations.

## 4. Validation and Docs

- [x] 4.1 Add e2e tests for adapter SDK lifecycle and semantic operation contracts.
- [x] 4.2 Add extension guide for adapter authors and multi-language refactor runbook.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/adapter-sdk-semantic-tooling/*` | Define SDK and semantic capability scope. | `openspec validate adapter-sdk-semantic-tooling --type change --strict --json --no-interactive` | Completed (2026-02-13) |
| 2.1 | [x] | `scripts/sbk.ps1`, `scripts/sbk-adapter.ps1`, `scripts/common/sbk-runtime.ps1` | Add adapter command family and plugin validation/register/doctor wiring. | `npx vitest run tests/e2e/sbk-adapter-semantic.e2e.test.ts` | Completed (2026-02-13) |
| 3.2 | [x] | `scripts/sbk-semantic.ps1`, `scripts/semantic-python.py`, `config/adapters/*.json` | Add multi-language semantic backend routing with fail-closed behavior and deterministic reports. | `npx vitest run tests/e2e/sbk-adapter-semantic.e2e.test.ts` | Completed (2026-02-13) |
| 4.2 | [x] | `tests/e2e/sbk-adapter-semantic.e2e.test.ts`, `docs/06-多项目类型接入与配置指南.md` | Add adapter SDK lifecycle and semantic operation runbook coverage. | `npx vitest run tests/e2e/sbk-adapter-semantic.e2e.test.ts` | Completed (2026-02-13) |
