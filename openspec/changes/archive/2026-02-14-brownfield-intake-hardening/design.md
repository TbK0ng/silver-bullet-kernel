## Context

Brownfield onboarding quality depends on reliable understanding of architecture and operational risk. Manual onboarding cannot scale to large codebases or teams with mixed discipline levels. We need deterministic intake artifacts and phase-based hardening.

## Goals / Non-Goals

**Goals**
- Generate deep intake reports from code and git metadata.
- Quantify onboarding risk with consistent scoring.
- Provide concrete hardening backlog and governance stage progression.
- Gate strict-mode adoption on explicit readiness checks.

**Non-Goals**
- Automatically fix legacy architecture debt.
- Replace product/domain decisions.
- Infer full business criticality without human input.

## Decisions

### Decision 1: Intake as first-class command family
Add:
- `sbk intake analyze --target-repo-root <path>`
- `sbk intake plan --target-repo-root <path>`
- `sbk intake verify --target-repo-root <path>`

### Decision 2: Structured intake artifacts
Outputs:
- `.metrics/intake-architecture-map.md/json`
- `.metrics/intake-risk-profile.md/json`
- `.metrics/intake-hardening-plan.md/json`

### Decision 3: Governance stage migration policy
Intake plan includes stage thresholds and required artifacts to unlock next governance level.

### Decision 4: Risk model includes operational dimensions
Risk scoring dimensions:
- test reliability
- change churn hotspots
- dependency freshness/security
- spec/doc drift
- ownership concentration

## Risks / Trade-offs

- [Risk] False positives in risk scoring can overwhelm teams.
  - Mitigation: score explanations and tunable thresholds.
- [Risk] Intake runtime may be heavy in very large monorepos.
  - Mitigation: incremental and cached analysis mode.

## Migration Plan

1. Define risk schema and intake output structure.
2. Implement analyze/plan/verify scripts.
3. Integrate stage progression with policy profile recommendations.
4. Add docs and adoption playbook.
