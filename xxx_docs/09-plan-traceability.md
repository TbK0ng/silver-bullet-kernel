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
- CI gate in `.github/workflows/ci.yml` uses `scripts/verify-ci.ps1`.

## Phase 3: Parallel and Conflict Governance

- Worktree policy codified in `.trellis/spec/guides/worktree-policy.md`.
- `.trellis/worktree.yaml` updated with `npm ci` and `npm run verify:fast`.
- Two-person SOP documented in `xxx_docs/04-two-person-collaboration.md`.

## Phase 4: Memory and Knowledge Governance

- Session policy documented in `AGENTS.md` (`/trellis:record-session`).
- Project-owned operational docs maintained under `xxx_docs/`.

## Phase 5: Observability and Improvement

- `scripts/map-codebase.ps1` generates `xxx_docs/generated/codebase-map.md`.
- Validation outcomes documented in `xxx_docs/07-appdemo-validation-report.md`.
- Completed OpenSpec change archived for audit trail:
  - `openspec/changes/archive/2026-02-12-bootstrap-codex-workflow-kernel/`
