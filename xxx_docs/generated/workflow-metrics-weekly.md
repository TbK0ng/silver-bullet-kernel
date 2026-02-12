# Workflow Metrics (Last 7 Days)

- generated_at_utc: 2026-02-12 10:04:43Z
- total_runs_all_time: 13
- runs_last_7_days: 13
- success_rate_last_7_days: 100%
- failure_rate_last_7_days: 0%

## Plan Indicators

- lead_time_p50_hours: 8.94
- lead_time_p90_hours: 9.22
- rework_count_last_7_days: 0
- parallel_throughput_active_changes: 0
- parallel_throughput_archived_changes_last_7_days: 4
- spec_drift_events_last_30_days: 1
- token_cost_status: available
- token_cost_total_usd: 0

## Verify Mode Summary

| Mode | Runs | Pass Rate (%) | Avg Duration (ms) |
| --- | ---: | ---: | ---: |
| fast | 3 | 100 | 9523.67 |
| full | 3 | 100 | 15174.33 |
| ci | 7 | 100 | 16909.57 |

## Top Failure Steps

- none

## Notes

- lead-time uses pre-archive proposal history when available; otherwise falls back to archive metadata + commit timestamps.
- drift detection counts src commits in last 30 days without openspec spec/change updates.
- token cost is reported only when .metrics/token-cost.json is present.
