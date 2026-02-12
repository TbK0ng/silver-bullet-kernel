## Context

The repository already enforces branch/worktree/change mapping and verification
entry points. The remaining gap is strictness: several philosophy rules are
"recommended" but not mechanically blocked.

This change converts those rules into policy-as-code checks and deterministic
tooling.

## Goals

1. Enforce security defaults without relying on operator memory.
2. Enforce executable task evidence quality, not only file presence.
3. Enforce memory governance with progressive disclosure and audit traces.
4. Enforce thin orchestrator boundaries as configuration-backed checks.
5. Keep indicator gate deterministic for CI.

## Non-Goals

- Replace OpenSpec/Trellis command surfaces.
- Introduce external services for secrets scanning.
- Build a general-purpose knowledge graph memory store.

## Decisions

### Decision 1: Security Gate is part of workflow policy

- Add `securityGate` config section in `workflow-policy.json`.
- Validate branch/working implementation deltas against denylisted path patterns.
- Scan changed durable artifacts (`.trellis/workspace`, `openspec`, `xxx_docs`)
  with configurable secret regex patterns.

Rationale:
- Aligns with plan point 1 gap #6 (security defaults).
- Keeps policy reviewable and versioned.

### Decision 2: Task evidence parser must validate section + data rows

- Require a canonical heading for task evidence table.
- Require required columns and at least one non-empty row.
- Enforce row-level granularity bounds from policy config.

Rationale:
- Aligns with plan point 3 rules #2 and #7.
- Prevents schema bypass with decorative headers.

### Decision 3: Progressive disclosure is a first-class script

- Add `scripts/memory-context.ps1`:
  - `-Stage index`: list relevant memory artifacts with IDs and summaries.
  - `-Stage detail -Ids`: fetch selected details only.
- Write audit line to `.metrics/memory-context-audit.jsonl`.

Rationale:
- Adopts claude-mem style staged retrieval in local, auditable form.
- Aligns with plan point 3 rule #9.

### Decision 4: Orchestrator boundary is policy-backed

- Add `orchestratorGate` config section:
  - target dispatcher agent file(s)
  - forbidden tools list
- Gate parses frontmatter and fails if forbidden tools appear.

Rationale:
- Aligns with plan point 3 rule #8.
- Converts convention to enforceable contract.

### Decision 5: CI metrics path is isolated

- Add configurable telemetry path resolution for verify and metrics scripts.
- `verify:ci` sets isolated metrics path to avoid local-history contamination.

Rationale:
- Keeps indicator checks deterministic in CI.
- Preserves local longitudinal metrics for weekly review.

## Risks and Mitigations

- Risk: Secret regex false positives.
  - Mitigation: configurable patterns and include/exclude path policy.
- Risk: Existing tasks format migrations.
  - Mitigation: explicit remediation text and template docs.
- Risk: Additional strict checks raise friction.
  - Mitigation: clear runbooks and deterministic failure reasons.
