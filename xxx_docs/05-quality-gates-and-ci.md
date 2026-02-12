# Quality Gates and CI

## Gate Definitions

- Fast local: `npm run verify:fast`
- Full local: `npm run verify`
- Bounded fix loop: `npm run verify:loop -- -Profile fast -MaxAttempts 2`
- CI strict: `npm run verify:ci`
- Policy gate: `npm run workflow:policy`
- Indicator gate: `npm run workflow:gate`

## CI Behavior

GitHub Actions workflow at `.github/workflows/ci.yml`:

- installs dependencies
- installs OpenSpec CLI
- runs `scripts/verify-ci.ps1`
- enforces workflow policy + indicator thresholds as blocking checks

## Why Single Verify Entry Matters

Using one script for CI and local verification:

- reduces drift between local and CI
- makes failures reproducible
- makes task evidence objective

## Required Evidence in Change Tasks

- `Files`: exact changed files
- `Action`: implementation intent
- `Verify`: exact command(s) run
- `Done`: objective outcome

Policy gate now fails if active change `tasks.md` does not include these columns.

## Telemetry

- Verify scripts append run telemetry to `.metrics/verify-runs.jsonl` (local only, gitignored).
- Weekly report generation:
  - `npm run metrics:collect`
  - outputs:
    - `xxx_docs/generated/workflow-metrics-weekly.md`
    - `xxx_docs/generated/workflow-metrics-latest.json`

## Workflow Doctor

- Run: `npm run workflow:doctor`
- Outputs:
  - `xxx_docs/generated/workflow-doctor.md`
  - `xxx_docs/generated/workflow-doctor.json`
- Use doctor before deep debugging to quickly isolate missing dependencies or broken project structure.

## Governance Gate Artifacts

- `npm run workflow:policy` outputs:
  - `xxx_docs/generated/workflow-policy-gate.md`
  - `xxx_docs/generated/workflow-policy-gate.json`
- `npm run workflow:gate` outputs:
  - `xxx_docs/generated/workflow-indicator-gate.md`
  - `xxx_docs/generated/workflow-indicator-gate.json`

## Policy Configuration

- Config file: `workflow-policy.json`
- Controls:
  - implementation-path mapping requirements
  - branch naming and change-owner mapping
  - linked worktree requirement for local implementation
  - required task evidence columns (`requiredTaskEvidenceColumns`)
  - session-evidence enforcement
  - CI fail-closed base-ref behavior
  - indicator thresholds and token-cost requirement mode

## CI Fail-Closed Note

- CI must provide resolvable base ref (`WORKFLOW_BASE_REF`).
- If base ref is missing/unresolvable, workflow policy gate fails CI (not warning).
- CI push uses `github.event.before` as base ref. If base resolves to `HEAD`, policy gate fails.
- Local `workflow:policy` may report warning for branch-delta availability when base ref is intentionally not provided.
