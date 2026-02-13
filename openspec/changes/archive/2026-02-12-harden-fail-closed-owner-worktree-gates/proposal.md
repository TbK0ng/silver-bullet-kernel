## Why

Current policy gate materially improves discipline, but two gaps remain against strict silver-bullet intent:

1. CI branch-delta checks can degrade to warnings when base ref is unavailable.
2. Owner/worktree rules are documented but not enforced as hard checks.

To satisfy strict execution philosophy, governance must fail-closed in CI and enforce owner/worktree isolation mechanically.

## What Changes

- Remove CI fallback behavior that weakens branch-delta checks.
- Require explicit base branch resolution in CI (`WORKFLOW_BASE_REF` or resolvable remote base).
- Enforce branch naming convention and change-to-branch mapping.
- Enforce local implementation on linked worktree (not main working tree).
- Enforce owner-specific session evidence path (`.trellis/workspace/<owner>/`) for implementation changes.
- Update CI workflow to provide full history and base ref.
- Update policy config and runbooks for strict owner/worktree governance.

## Capabilities

### New Capabilities

- strict-owner-worktree-enforcement: policy gate validates owner naming, change mapping, and linked worktree usage.

### Modified Capabilities

- codex-workflow-kernel: CI policy checks become fail-closed.
- memory-governance-policy: session evidence must align with change owner.
- workflow-docs-system: strict branch/worktree operational guidance.

## Impact

- Affected code:
  - `scripts/workflow-policy-gate.ps1`
  - `workflow-policy.json`
  - `.github/workflows/ci.yml`
- Affected docs:
  - `.trellis/spec/guides/worktree-policy.md`
  - `.trellis/spec/guides/memory-governance.md`
  - `docs/04-two-person-collaboration.md`
  - `docs/05-quality-gates-and-ci.md`
  - `docs/08-troubleshooting.md`
  - `docs/09-plan-traceability.md`
- Affected specs:
  - `codex-workflow-kernel`
  - `memory-governance-policy`
  - `workflow-docs-system`
