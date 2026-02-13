## 1. Adapter SDK Contract

- [ ] 1.1 Define adapter SDK schema and registry contract.
- [ ] 1.2 Define strict-mode activation rules for plugin adapters.

## 2. Adapter Command Runtime

- [ ] 2.1 Add `sbk adapter list/register/validate/doctor` commands.
- [ ] 2.2 Implement adapter plugin validation and registry write flow.

## 3. Semantic Tooling Expansion

- [ ] 3.1 Define cross-language semantic operation API.
- [ ] 3.2 Implement backend integrations for Python/Go/Java/Rust capabilities.
- [ ] 3.3 Add deterministic reporting and audit outputs for semantic operations.

## 4. Validation and Docs

- [ ] 4.1 Add e2e tests for adapter SDK lifecycle and semantic operation contracts.
- [ ] 4.2 Add extension guide for adapter authors and multi-language refactor runbook.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [ ] | `openspec/changes/adapter-sdk-semantic-tooling/*` | Define SDK and semantic capability scope. | `openspec validate adapter-sdk-semantic-tooling --type change --strict --json --no-interactive` | Pending |
| 2.1 | [ ] | `scripts/sbk.ps1`, `scripts/*adapter*.ps1` | Add adapter command family and validation wiring. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1` | Pending |
| 3.2 | [ ] | `scripts/*semantic*`, `config/adapters/**` | Add multi-language semantic operation backends and capability wiring. | `npx vitest run tests/e2e/*semantic*.test.ts` | Pending |
| 4.2 | [ ] | `docs/**` | Add adapter SDK extension and semantic tooling runbooks. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Pending |
