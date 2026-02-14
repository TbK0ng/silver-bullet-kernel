## 1. Fleet Observability Contract

- [x] 1.1 Define fleet metrics schema and aggregate indicator model.
- [x] 1.2 Define command contract for fleet collect/report/doctor.

## 2. Runtime and Metrics Implementation

- [x] 2.1 Add `sbk fleet` command family and aggregation script flow.
- [x] 2.2 Implement fleet snapshot outputs and trend reporting.

## 3. Release Channel Governance

- [x] 3.1 Define kernel/blueprint release manifest schema with stable/beta channels.
- [x] 3.2 Add channel compatibility and rollout safety gate checks.

## 4. Validation and Docs

- [x] 4.1 Add e2e tests for fleet collection and channel policy checks.
- [x] 4.2 Add rollout playbook for channel-based operations.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/workflow-control-plane-observability/*` | Define control-plane and channel governance scope. | `openspec validate workflow-control-plane-observability --type change --strict --json --no-interactive` | Completed (2026-02-13) |
| 2.1 | [x] | `scripts/sbk.ps1`, `scripts/sbk-fleet.ps1` | Add fleet command family and aggregation execution path. | `npx vitest run tests/e2e/sbk-fleet-channel.e2e.test.ts` | Completed (2026-02-13) |
| 3.2 | [x] | `scripts/sbk-install.ps1`, `workflow-policy.json`, `config/release/channels/*.json`, `scripts/workflow-policy-gate.ps1` | Add channel compatibility checks, rollout audit artifacts, and policy gate safety enforcement. | `npx vitest run tests/e2e/sbk-fleet-channel.e2e.test.ts` | Completed (2026-02-13) |
| 4.2 | [x] | `tests/e2e/sbk-fleet-channel.e2e.test.ts`, `docs/06-多项目类型接入与配置指南.md` | Add fleet/channel e2e coverage and rollout guidance. | `npx vitest run tests/e2e/sbk-fleet-channel.e2e.test.ts` | Completed (2026-02-13) |
