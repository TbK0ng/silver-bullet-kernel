# Memory Governance and Observability

## Goal

Close plan phase 4 and phase 5 with executable, auditable operations.

## Memory Governance

Policy files:

- `.trellis/spec/guides/constitution.md`
- `.trellis/spec/guides/memory-governance.md`

Operational rules:

1. Record key session outcomes in Trellis workspace journals.
2. Keep secrets out of all persisted memory artifacts.
3. Promote stable lessons to guides/docs, not ephemeral chat memory.

## Observability

Telemetry source:

- `.metrics/verify-runs.jsonl` (local, gitignored)

Generation command:

- `npm run metrics:collect`

Generated artifacts:

- `xxx_docs/generated/workflow-metrics-weekly.md`
- `xxx_docs/generated/workflow-metrics-latest.json`
- `xxx_docs/generated/workflow-doctor.md`
- `xxx_docs/generated/workflow-doctor.json`
- `xxx_docs/generated/workflow-policy-gate.md`
- `xxx_docs/generated/workflow-policy-gate.json`
- `xxx_docs/generated/workflow-indicator-gate.md`
- `xxx_docs/generated/workflow-indicator-gate.json`

## Weekly Review Routine

1. Run `npm run verify:ci`.
2. Run `npm run workflow:doctor`.
3. Run `npm run metrics:collect`.
4. Run `npm run workflow:gate`.
5. Review:
   - lead time p50/p90
   - success/failure rate
   - per-mode runtime
   - top failed steps
   - rework count
   - parallel throughput
   - spec drift count
   - token cost status
6. Update guardrails/guides for the top failure and drift trends.

## Indicator Thresholds

- `last7DaysFailureRate`: keep <= 5%; if > 10%, stop new features and fix gate stability first.
- `leadTimeHoursP90`: keep <= 48h for routine changes; if > 72h, split scope and reduce change batch size.
- `reworkCountLast7Days`: keep <= 1; if > 2, add pre-implementation design review and stronger acceptance checks.
- `specDriftEventsLast30Days`: target 0; any non-zero value requires immediate spec backfill.
- `parallelThroughput.activeChanges`: keep <= 3 for a two-person team; if higher, enforce WIP limits.
- `tokenCost.status`: should be `available`; if unavailable for > 2 consecutive weeks, add cost-export integration.

## Token Cost Integration

- Publish token-cost summary when provider usage is available:
  - `npm run metrics:token-cost -- -Source <provider> -TotalCostUsd <amount> -TotalInputTokens <n> -TotalOutputTokens <n>`
- After publishing, rerun:
  - `npm run metrics:collect`
  - `npm run workflow:gate`

## Tuning Directions

1. If failure rate rises, tighten `verify:fast` checks and move flaky checks from optional to required.
2. If lead time rises, split changes into smaller OpenSpec units and archive earlier.
3. If drift events appear, require spec delta creation before touching `src/`.
4. If throughput stalls, freeze new starts and finish in-flight changes to archive.

## Session Recovery Proof

Committed sample:

- `.trellis/workspace/sample-owner/index.md`
- `.trellis/workspace/sample-owner/journal-1.md`
- `.trellis/workspace/sample-owner/journal-2.md`
