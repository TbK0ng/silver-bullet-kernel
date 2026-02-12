# Workflow Metrics (Last 7 Days)

- generated_at_utc: 2026-02-12 08:55:06Z
- total_runs_all_time: 5
- runs_last_7_days: 5
- success_rate_last_7_days: 100%
- active_changes: 0
- archived_changes: 2

## Verify Mode Summary

| Mode | Runs | Pass Rate (%) | Avg Duration (ms) |
| --- | ---: | ---: | ---: |
| fast | 1 | 100 | 7141 |
| full | 1 | 100 | 11097 |
| ci | 3 | 100 | 15389.67 |

## Top Failure Steps

- none

## Suggested Actions

- Keep `verify:fast` under 120s median for tight local loops.
- If `ci` failures increase, inspect `failedStep` trend and add targeted guardrails.
- Review change throughput weekly (`active_changes` vs `archived_changes`).
