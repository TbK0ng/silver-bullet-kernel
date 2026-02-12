# Plan Traceability

This document maps `ai-coding-workflow-silver-bullet-plan.md` requirements to concrete implementation in this repository.

## Phase 0: Constraints and Baseline

- Runtime policy set in `AGENTS.md` and `CLAUDE.md`.
- Baseline verify commands defined in `scripts/verify-fast.ps1`, `scripts/verify.ps1`, `scripts/verify-ci.ps1`.
- Brownfield onboarding checklist documented in `xxx_docs/02-brownfield-onboarding.md`.

## Phase 1: Skeleton and Directory Standards

- Trellis initialized with Codex and Claude assets under `.trellis/`, `.codex/`, `.claude/`.
- OpenSpec initialized with canonical structure under `openspec/`.
- Guide files added:
  - `.trellis/spec/guides/quality-gates.md`
  - `.trellis/spec/guides/worktree-policy.md`
  - `.trellis/spec/guides/openspec-workflow.md`

## Phase 2: Hard Acceptance Gates

- Verify scripts enforce lint/typecheck/test/build and OpenSpec strict validation.
- Verify scripts enforce workflow policy gate for artifact/session discipline.
- Active change task evidence schema (`Files/Action/Verify/Done`) enforced in policy gate.
- CI gate in `.github/workflows/ci.yml` uses `scripts/verify-ci.ps1`.

## Phase 3: Parallel and Conflict Governance

- Worktree policy codified in `.trellis/spec/guides/worktree-policy.md`.
- `.trellis/worktree.yaml` updated with `npm ci` and `npm run verify:fast`.
- Two-person SOP documented in `xxx_docs/04-two-person-collaboration.md`.
- Strict branch/owner/worktree enforcement implemented in `scripts/workflow-policy-gate.ps1`.

## Phase 4: Memory and Knowledge Governance

- Session policy documented in `AGENTS.md` (`/trellis:record-session`).
- Constitution and memory governance policy added:
  - `.trellis/spec/guides/constitution.md`
  - `.trellis/spec/guides/memory-governance.md`
- Session recovery sample committed:
  - `.trellis/workspace/sample-owner/index.md`
  - `.trellis/workspace/sample-owner/journal-1.md`
- Project-owned operational docs maintained under `xxx_docs/`.

## Phase 5: Observability and Improvement

- `scripts/map-codebase.ps1` generates `xxx_docs/generated/codebase-map.md`.
- Verify scripts emit telemetry to `.metrics/verify-runs.jsonl`.
- `scripts/verify-loop.ps1` emits verify/fix loop evidence to `.metrics/verify-fix-loop.jsonl`.
- `scripts/semantic-rename.ts` provides TypeScript semantic refactor command for deterministic rename operations.
- `scripts/collect-metrics.ps1` generates:
  - `xxx_docs/generated/workflow-metrics-weekly.md`
  - `xxx_docs/generated/workflow-metrics-latest.json`
- `scripts/workflow-doctor.ps1` generates:
  - `xxx_docs/generated/workflow-doctor.md`
  - `xxx_docs/generated/workflow-doctor.json`
- `scripts/workflow-policy-gate.ps1` generates:
  - `xxx_docs/generated/workflow-policy-gate.md`
  - `xxx_docs/generated/workflow-policy-gate.json`
- `scripts/workflow-indicator-gate.ps1` generates:
  - `xxx_docs/generated/workflow-indicator-gate.md`
  - `xxx_docs/generated/workflow-indicator-gate.json`
- `workflow-policy.json` defines gate rules and thresholds as policy-as-code.
- Validation outcomes documented in `xxx_docs/07-appdemo-validation-report.md`.
- OpenSpec archive trail:
  - `openspec/changes/archive/2026-02-12-bootstrap-codex-workflow-kernel/`
  - `openspec/changes/archive/2026-02-12-complete-phase4-phase5-governance/`
  - `openspec/changes/archive/2026-02-12-add-workflow-doctor-and-advanced-metrics/`
  - `openspec/changes/archive/2026-02-12-enforce-workflow-policy-gates/`
  - `openspec/changes/archive/2026-02-12-harden-fail-closed-owner-worktree-gates/`
  - `openspec/changes/archive/2026-02-12-close-gap-13-thought-enforcement/`
