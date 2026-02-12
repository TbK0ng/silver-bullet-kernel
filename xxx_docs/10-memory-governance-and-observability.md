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

## Weekly Review Routine

1. Run `npm run verify:ci`.
2. Run `npm run metrics:collect`.
3. Review:
   - success rate
   - per-mode runtime
   - top failed steps
4. Update guardrails/guides for the top failure trend.

## Session Recovery Proof

Committed sample:

- `.trellis/workspace/sample-owner/index.md`
- `.trellis/workspace/sample-owner/journal-1.md`
