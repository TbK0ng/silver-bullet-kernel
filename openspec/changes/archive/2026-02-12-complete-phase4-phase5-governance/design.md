## Context

The workflow kernel currently proves planning and execution, but governance and observability are still lightweight. To finish the plan, memory policy must be explicit and measurable outcomes must be generated from real verify runs.

## Goals / Non-Goals

**Goals:**

- Add constitution-level guardrails.
- Add explicit memory governance and retention policy.
- Emit verify run telemetry for fast/full/ci flows.
- Generate weekly metrics report from telemetry.
- Keep session recovery proof in-repo with sample workspace journal.

**Non-Goals:**

- Building a remote analytics service.
- Storing sensitive runtime artifacts in git.
- Replacing OpenSpec/Trellis native mechanisms.

## Decisions

- Store raw verify telemetry in local `.metrics/verify-runs.jsonl` (gitignored).
- Store weekly report in `xxx_docs/generated/` for shareable visibility.
- Treat constitution and memory governance as Trellis guides to remain runtime-agnostic.
- Commit a sample workspace journal for format and recovery proof.

## Risks / Trade-offs

- Local-only telemetry can diverge across machines. Mitigated by generated markdown summary committed as project artifact.
- Added scripts increase operational surface. Mitigated by single entry command `npm run metrics:collect`.
