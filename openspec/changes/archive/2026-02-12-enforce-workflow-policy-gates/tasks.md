## 1. Enforce Workflow Policy

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `scripts/workflow-policy-gate.ps1`, `workflow-policy.json` | Implement structural policy gate with working-tree and branch-delta checks. | `npm run workflow:policy` | Gate fails when implementation changes are not mapped to change/session artifacts. |
| 1.2 | [x] | `scripts/verify-fast.ps1`, `scripts/verify.ps1`, `scripts/verify-ci.ps1`, `package.json` | Integrate policy gate into verify entry points. | `npm run verify:fast` | Verify flow blocks on policy violations. |

## 2. Enforce Indicator Thresholds

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 2.1 | [x] | `scripts/workflow-indicator-gate.ps1`, `workflow-policy.json` | Implement threshold gate against generated metrics snapshot. | `npm run workflow:gate` | Threshold breaches return actionable failures/warnings. |
| 2.2 | [x] | `scripts/verify-ci.ps1`, `scripts/collect-metrics.ps1` | Ensure CI runs metrics collection before indicator gate check. | `npm run verify:ci` | CI enforces indicator policy. |

## 3. Doctor and Token-Cost Integration

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 3.1 | [x] | `scripts/workflow-doctor.ps1` | Include policy and indicator gate health checks in doctor report. | `npm run workflow:doctor` | Doctor exposes governance readiness. |
| 3.2 | [x] | `scripts/update-token-cost.ps1`, `package.json` | Add token-cost ingestion script and command for optional cost tracking. | `npm run metrics:token-cost -- -Source manual -TotalCostUsd 0` | Metrics can move from unavailable to available token-cost status. |

## 4. Documentation and Spec Sync

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 4.1 | [x] | `README.md`, `.trellis/spec/guides/*.md`, `docs/*.md` | Document hard-gate SOP, threshold tuning, and remediation flow. | Manual review + command outputs | Docs describe real enforced behavior. |
| 4.2 | [x] | `openspec/changes/enforce-workflow-policy-gates/specs/**` | Add capability deltas for policy/indicator/session-evidence enforcement. | `openspec validate --all --strict --no-interactive` | Specs validate and match implementation. |
