## Context

The repository currently expresses strong engineering intent, but most constraints are documentary. This creates two failure modes:

1. policy drift: contributors can run verification without required change artifacts.
2. observability drift: indicators are generated but not tied to decisions or merge gates.

This change introduces executable governance while keeping configuration explicit and local to the repository.

## Goals / Non-Goals

**Goals**

- Make artifact-first change control enforceable at verify time.
- Make process-indicator thresholds executable as a policy gate.
- Keep policy behavior configurable in-repo (`workflow-policy.json`).
- Keep implementation shell-native and CI-friendly.

**Non-Goals**

- Building a cloud analytics backend.
- Replacing OpenSpec lifecycle commands.
- Forcing a single memory backend beyond current Trellis/OpenSpec/doc artifacts.

## Decisions

### Decision 1: Separate policy gate from indicator gate

- `workflow-policy-gate.ps1` focuses on structural/process conformance.
- `workflow-indicator-gate.ps1` focuses on metric thresholds and trend breaches.

This separation keeps failures interpretable and remediation targeted.

### Decision 2: Evaluate both working-tree and branch-delta signals

- Working-tree checks catch local bypass early.
- Branch-delta checks catch CI-time governance violations for merged histories.

Branch delta uses merge-base against configurable base ref (`WORKFLOW_BASE_REF`, default `origin/main` if available).

### Decision 3: Config-as-code policy file

Use `workflow-policy.json` to avoid hard-coded hidden rules and to make governance tunable by review.

### Decision 4: Session evidence as enforceable CI rule

For implementation changes, CI gate requires session evidence under `.trellis/workspace/**`.
This aligns with “context is RAM; durable decisions must be written to artifacts.”

## Risks / Trade-offs

- Branch-delta checks depend on base ref availability in local clones; script degrades gracefully with explicit remediation.
- Session-evidence enforcement increases discipline cost, but this is intentional for recoverability.
- Threshold gates can be noisy if set too strict; config file keeps tuning explicit and auditable.
