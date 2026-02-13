## Context

For a workflow project, usability depends on operational clarity: contributors need to know if the environment is healthy and whether process quality is improving. Current tooling gives partial insight but not complete phase-5 indicators.

## Goals / Non-Goals

**Goals:**

- Provide one command that diagnoses project workflow readiness.
- Compute all plan-defined indicators from local artifacts.
- Keep implementation shell-native and deterministic.
- Output artifacts in markdown/json for human and machine consumption.

**Non-Goals:**

- Remote telemetry ingestion.
- Proprietary analytics backend.
- Perfect semantic interpretation of all rework causes.

## Decisions

- Implement doctor as PowerShell script for environment consistency.
- Keep metrics source local (`.metrics/verify-runs.jsonl` + git/OpenSpec metadata).
- Emit doctor/metrics reports under `docs/generated/`.
- Treat unavailable token-cost data as explicit `status: unavailable`.

## Risks / Trade-offs

- Git-history-derived lead time is approximate in edge cases.
- Drift detection is heuristic (commit-level pattern matching), not semantic diff.
- Local-only telemetry can miss cross-machine runs; weekly reports remain repository-visible.
