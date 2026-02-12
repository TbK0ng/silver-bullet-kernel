# Workflow Metrics (Last 7 Days)

- generated_at_utc: 2026-02-12 11:26:51Z
- total_runs_all_time: 0
- runs_last_7_days: 0
- success_rate_last_7_days: 0%
- failure_rate_last_7_days: 0%

## Plan Indicators

- lead_time_p50_hours: 9.22
- lead_time_p90_hours: 10.65
- rework_count_last_7_days: 0
- parallel_throughput_active_changes: 1
- parallel_throughput_archived_changes_last_7_days: 5
- spec_drift_events_last_30_days: 1
- token_cost_status: unavailable

## Verify Mode Summary

| Mode | Runs | Pass Rate (%) | Avg Duration (ms) |
| --- | ---: | ---: | ---: |
| fast | 0 | 0 | 0 |
| full | 0 | 0 | 0 |
| ci | 0 | 0 | 0 |

## Top Failure Steps

- none

## Notes

- lead-time uses pre-archive proposal history when available; otherwise falls back to archive metadata + commit timestamps.
- drift detection counts src commits in last 30 days without openspec spec/change updates.
- token cost is reported only when .metrics/token-cost.json is present.
