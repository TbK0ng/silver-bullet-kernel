## Why

The workflow kernel already has high-quality runbooks and reports, but core rules are still mostly social contracts. Contributors can still bypass artifact-first change control, skip session evidence, and ignore indicator thresholds without hard failure.

To realize the silver-bullet philosophy in `ai-coding-workflow-silver-bullet-plan.md`, policy rules must be executable and blocking, not advisory.

## What Changes

- Add a `workflow-policy-gate` script that enforces:
  - implementation work maps to OpenSpec change artifacts
  - active change artifacts are complete before verify succeeds
  - CI branch deltas include change artifacts and session evidence
- Add a `workflow-indicator-gate` script that turns observability thresholds into pass/fail governance checks.
- Integrate policy and indicator gates into verify workflows.
- Extend workflow doctor to include these governance checks.
- Add token-cost input script and docs so token-cost signal can be integrated instead of staying permanently unavailable.
- Update docs and best-practice runbooks with enforceable SOP.

## Capabilities

### New Capabilities

- `workflow-policy-gate`: enforceable workflow-policy execution gate.
- `workflow-indicator-gate`: threshold-based process governance gate.

### Modified Capabilities

- `codex-workflow-kernel`: add blocking change-control enforcement.
- `workflow-observability`: add threshold-driven action gate.
- `workflow-doctor`: include governance gate checks.
- `memory-governance-policy`: require session evidence for implemented changes.
- `workflow-docs-system`: document policy config and operational remediations.

## Impact

- Affected code:
  - `scripts/workflow-policy-gate.ps1`
  - `scripts/workflow-indicator-gate.ps1`
  - `scripts/update-token-cost.ps1`
  - `scripts/verify-fast.ps1`
  - `scripts/verify.ps1`
  - `scripts/verify-ci.ps1`
  - `scripts/workflow-doctor.ps1`
  - `package.json`
  - `workflow-policy.json`
- Affected docs:
  - `README.md`
  - `.trellis/spec/guides/quality-gates.md`
  - `.trellis/spec/guides/memory-governance.md`
  - `xxx_docs/*`
- Affected specs:
  - `codex-workflow-kernel`
  - `workflow-observability`
  - `workflow-doctor`
  - `memory-governance-policy`
  - `workflow-docs-system`
