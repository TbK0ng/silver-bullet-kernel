## Why

The repository has a working kernel and demo, but plan phases 4 and 5 are not fully operationalized yet. We need concrete memory-governance rules and executable observability tooling so the workflow can be continuously improved with evidence.

## What Changes

- Add explicit constitution and memory governance specs under Trellis guides.
- Add verify-run telemetry logging as project-owned metrics artifacts.
- Add weekly metrics aggregation script and report output.
- Add committed workspace journal sample for context recovery proof.
- Extend docs and traceability to include governance and metrics operations.

## Capabilities

### New Capabilities

- `memory-governance-policy`: auditable memory retention and injection policy.
- `workflow-observability`: capture and summarize operational metrics from verify executions and OpenSpec activity.
- `session-recovery-proof`: committed journal sample showing recoverable history format.

### Modified Capabilities

- `codex-workflow-kernel`: add phase-4/5 operational requirements and measurable governance enforcement.
- `workflow-docs-system`: extend runbooks with governance and observability procedures.

## Impact

- Affected code: `scripts/verify*.ps1`, `scripts/collect-metrics.ps1`, `package.json`
- Affected policy: `.trellis/spec/guides/*`, `AGENTS.md`
- Affected docs: `xxx_docs/*`, `openspec/specs/*`
