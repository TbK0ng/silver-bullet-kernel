# Workflow Metrics (Last 7 Days)

- generated_at_utc: 2026-02-12 12:25:55Z
- metrics_source_path: E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\.metrics\verify-runs.jsonl
- total_runs_all_time: 4
- runs_last_7_days: 4
- success_rate_last_7_days: 100%
- failure_rate_last_7_days: 0%

## Plan Indicators

- lead_time_p50_hours: 9.22
- lead_time_p90_hours: 11.48
- rework_count_last_7_days: 0
- parallel_throughput_active_changes: 0
- parallel_throughput_archived_changes_last_7_days: 7
- spec_drift_events_last_30_days: 1
- token_cost_status: unavailable

## Verify Mode Summary

| Mode | Runs | Pass Rate (%) | Avg Duration (ms) |
| --- | ---: | ---: | ---: |
| fast | 2 | 100 | 12367 |
| full | 2 | 100 | 33162 |
| ci | 0 | 0 | 0 |

## Top Failure Steps

- none

## Notes

- lead-time uses pre-archive proposal history when available; otherwise falls back to archive metadata + commit timestamps.
- drift detection counts src commits in last 30 days without openspec spec/change updates.
- token cost is reported only when .metrics/token-cost.json is present.
- metrics source path can be overridden via WORKFLOW_VERIFY_RUNS_PATH or -MetricsPath.
