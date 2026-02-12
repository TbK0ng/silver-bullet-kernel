# Workflow Indicator Gate

- generated_at_utc: 2026-02-12 10:38:11Z
- outcome: PASS

## Checks

| Check | Severity | Status | Observed | Threshold | Remediation |
| --- | --- | --- | --- | --- | --- |
| Verify failure rate within threshold | fail | PASS | 0% | <= 5% | Investigate top failed steps and stabilize verify gates before adding new scope. |
| Lead time P90 within threshold | warn | PASS | 10.11 h | <= 72 h | Split oversized changes and archive in smaller batches. |
| Rework count within threshold | fail | PASS | 0 | <= 2 | Strengthen proposal/design clarity and pre-implementation acceptance checks. |
| Active change WIP within threshold | fail | PASS | 0 | <= 3 | Pause new starts and close in-flight changes to maintain throughput quality. |
| Spec drift events within threshold | fail | PASS | 1 | <= 1 | Backfill missing specs/changes for drifted commits and enforce change-first workflow. |
| Token cost status available | warn | PASS | available | recommended: available | Run npm run metrics:token-cost -- -Source <provider> -TotalCostUsd <amount> to publish token-cost summary. |
