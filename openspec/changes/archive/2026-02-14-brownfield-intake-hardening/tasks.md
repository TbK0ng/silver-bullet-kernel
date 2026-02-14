## 1. Intake Model and Artifact Contract

- [x] 1.1 Define intake risk schema and scoring dimensions.
- [x] 1.2 Define output artifact schema for analyze/plan/verify stages.

## 2. Runtime Commands

- [x] 2.1 Add `sbk intake analyze` command and report generation.
- [x] 2.2 Add `sbk intake plan` command for staged hardening backlog.
- [x] 2.3 Add `sbk intake verify` command for strict-mode readiness checks.

## 3. Policy and Profile Integration

- [x] 3.1 Connect intake outputs to governance stage recommendations.
- [x] 3.2 Add threshold overrides in runtime configuration.

## 4. Validation and Docs

- [x] 4.1 Add e2e tests for intake command flow and artifact outputs.
- [x] 4.2 Add brownfield adoption playbook and migration guidance.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/brownfield-intake-hardening/*` | Define intake capability and acceptance scenarios. | `openspec validate brownfield-intake-hardening --type change --strict --json --no-interactive` | Completed (2026-02-13) |
| 2.1 | [x] | `scripts/sbk.ps1`, `scripts/sbk-intake.ps1` | Add intake command family with analyze/plan/verify report generation. | `npx vitest run tests/e2e/sbk-intake.e2e.test.ts` | Completed (2026-02-13) |
| 3.1 | [x] | `workflow-policy.json`, `sbk.config.json`, `scripts/workflow-policy-gate.ps1` | Add threshold override model and policy integration points for staged governance. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1 -Mode local -NoReport -Quiet` | Completed (2026-02-13) |
| 4.2 | [x] | `tests/e2e/sbk-intake.e2e.test.ts`, `docs/06-多项目类型接入与配置指南.md` | Add intake flow e2e coverage and brownfield migration guidance. | `npx vitest run tests/e2e/sbk-intake.e2e.test.ts` | Completed (2026-02-13) |
