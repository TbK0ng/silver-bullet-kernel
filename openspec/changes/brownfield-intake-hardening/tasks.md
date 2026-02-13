## 1. Intake Model and Artifact Contract

- [ ] 1.1 Define intake risk schema and scoring dimensions.
- [ ] 1.2 Define output artifact schema for analyze/plan/verify stages.

## 2. Runtime Commands

- [ ] 2.1 Add `sbk intake analyze` command and report generation.
- [ ] 2.2 Add `sbk intake plan` command for staged hardening backlog.
- [ ] 2.3 Add `sbk intake verify` command for strict-mode readiness checks.

## 3. Policy and Profile Integration

- [ ] 3.1 Connect intake outputs to governance stage recommendations.
- [ ] 3.2 Add threshold overrides in runtime configuration.

## 4. Validation and Docs

- [ ] 4.1 Add e2e tests for intake command flow and artifact outputs.
- [ ] 4.2 Add brownfield adoption playbook and migration guidance.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [ ] | `openspec/changes/brownfield-intake-hardening/*` | Define intake capability and acceptance scenarios. | `openspec validate brownfield-intake-hardening --type change --strict --json --no-interactive` | Pending |
| 2.1 | [ ] | `scripts/*intake*.ps1`, `scripts/sbk.ps1` | Add intake command family and report generation path. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1` | Pending |
| 3.1 | [ ] | `workflow-policy.json`, `sbk.config.json` | Add profile progression and threshold integration hooks. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1 -Mode local` | Pending |
| 4.2 | [ ] | `docs/**` | Add brownfield hardening runbook. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Pending |
