## Why

The current workflow kernel has strong governance, but sections 1-3 of
`ai-coding-workflow-silver-bullet-plan.md` are still not fully strict in four
areas:

1. Security policy is documented but not enforced as fail-closed policy-as-code.
2. Active change task evidence can be bypassed with weak table content.
3. Memory governance references progressive disclosure, but lacks executable and
   auditable enforcement.
4. The thin-orchestrator/thick-executor principle is mostly convention, not a
   gate.

To fully implement the plan philosophy, these rules must become executable and
blocking.

## What Changes

- Add security policy-as-code and fail-closed security checks:
  - denylist sensitive file paths in implementation deltas
  - secret-pattern scanning for durable artifacts
- Harden tasks evidence validation:
  - enforce required columns under a canonical task-evidence section
  - require at least one non-empty executable evidence row
  - enforce bounded task granularity policy values from config
- Add progressive disclosure memory tooling:
  - index/detail staged memory retrieval script
  - auditable retrieval log output
  - owner-scoped session evidence structure checks
- Enforce thin orchestrator governance:
  - validate dispatcher agent toolset against policy (no write/edit tools)
- Make indicator gating deterministic in CI:
  - isolate CI telemetry input path from local historical metrics

## Impact

- Affected specs:
  - `codex-workflow-kernel`
  - `memory-governance-policy`
  - `workflow-observability`
  - `workflow-docs-system`
  - `workflow-security-policy` (new capability)
- Affected systems:
  - `workflow-policy.json`
  - `scripts/workflow-policy-gate.ps1`
  - `scripts/collect-metrics.ps1`
  - `scripts/common/verify-telemetry.ps1`
  - `scripts/verify-ci.ps1`
  - new memory context tooling and docs
