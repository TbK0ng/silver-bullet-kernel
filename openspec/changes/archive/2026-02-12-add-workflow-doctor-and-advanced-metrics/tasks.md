## 1. Add Workflow Doctor

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `scripts/workflow-doctor.ps1`, `package.json` | Add doctor command that checks runtime versions, required directories, OpenSpec status, and telemetry presence. | `npm run workflow:doctor` | Doctor command generates markdown/json outputs and exits with pass/fail summary. |
| 1.2 | [x] | `xxx_docs/generated/workflow-doctor.md`, `xxx_docs/generated/workflow-doctor.json` | Ensure doctor writes machine + human readable reports. | `npm run workflow:doctor` | Generated reports are created and contain check results. |

## 2. Extend Metrics to Full Indicator Set

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 2.1 | [x] | `scripts/collect-metrics.ps1` | Extend metrics collector with lead time P50/P90, failure rates, rework counts, throughput, drift events, token-cost status. | `npm run metrics:collect` | Weekly metrics include all plan-defined indicators. |
| 2.2 | [x] | `xxx_docs/generated/workflow-metrics-weekly.md`, `xxx_docs/generated/workflow-metrics-latest.json` | Regenerate reports with expanded schema and fields. | `npm run metrics:collect` | Generated artifacts show advanced indicators. |

## 3. Documentation and Spec Sync

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 3.1 | [x] | `README.md`, `xxx_docs/05-quality-gates-and-ci.md`, `xxx_docs/10-memory-governance-and-observability.md`, `xxx_docs/09-plan-traceability.md` | Document doctor and advanced metrics usage/interpretation. | Manual review + command outputs. | Runbooks include operational guidance and phase traceability updates. |
| 3.2 | [x] | `openspec/changes/add-workflow-doctor-and-advanced-metrics/specs/**` | Add/modify capability deltas for doctor and advanced indicators. | `openspec validate --all --strict --no-interactive` | Specs validate successfully. |
