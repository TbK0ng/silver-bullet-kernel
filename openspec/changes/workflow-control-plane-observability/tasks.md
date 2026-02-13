## 1. Fleet Observability Contract

- [ ] 1.1 Define fleet metrics schema and aggregate indicator model.
- [ ] 1.2 Define command contract for fleet collect/report/doctor.

## 2. Runtime and Metrics Implementation

- [ ] 2.1 Add `sbk fleet` command family and aggregation script flow.
- [ ] 2.2 Implement fleet snapshot outputs and trend reporting.

## 3. Release Channel Governance

- [ ] 3.1 Define kernel/blueprint release manifest schema with stable/beta channels.
- [ ] 3.2 Add channel compatibility and rollout safety gate checks.

## 4. Validation and Docs

- [ ] 4.1 Add e2e tests for fleet collection and channel policy checks.
- [ ] 4.2 Add rollout playbook for channel-based operations.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [ ] | `openspec/changes/workflow-control-plane-observability/*` | Define control-plane and channel governance scope. | `openspec validate workflow-control-plane-observability --type change --strict --json --no-interactive` | Pending |
| 2.1 | [ ] | `scripts/sbk.ps1`, `scripts/*fleet*.ps1` | Add fleet command family and aggregation execution path. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1` | Pending |
| 3.2 | [ ] | `workflow-policy.json`, `config/**` | Add channel safety policy and compatibility checks. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1 -Mode local` | Pending |
| 4.2 | [ ] | `docs/**` | Add fleet and release-channel rollout runbook. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Pending |
