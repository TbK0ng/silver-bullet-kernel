# Appdemo Validation Report

## Scope

Validate that the workflow kernel can deliver a runnable application artifact with deterministic checks.

## Test Targets

- `GET /health`
- `POST /api/tasks`
- `GET /api/tasks`
- `PATCH /api/tasks/:id`

## Verification Commands

- `npm run test`
- `npm run test:e2e`
- `npm run demo:smoke`
- `npm run verify`

## Result

- Status: `PASS` (validated on 2026-02-12)
- Evidence:
  - `npm run verify:fast` passed.
  - `npm run verify` passed.
  - `npm run metrics:collect` passed and generated weekly metrics artifacts.
  - `npm run demo:smoke` passed with `health=ok` and `count=1`.
  - `npm run verify:ci` passed including strict OpenSpec validation.
  - `openspec status --change bootstrap-codex-workflow-kernel` reached `4/4 artifacts complete` before archive.
  - `openspec archive bootstrap-codex-workflow-kernel -y` succeeded and merged delta specs.
  - `openspec status --change complete-phase4-phase5-governance` reached `4/4 artifacts complete` before archive.
  - `openspec archive complete-phase4-phase5-governance -y` succeeded and merged governance/observability deltas.
  - `openspec status --change add-workflow-doctor-and-advanced-metrics` reached `4/4 artifacts complete` before archive.
  - `openspec archive add-workflow-doctor-and-advanced-metrics -y` succeeded and merged doctor/advanced-metrics deltas.
  - `openspec validate --all --strict --no-interactive` passed for canonical specs.
  - `openspec list` returns no active changes after second archive.
  - `openspec list` returns no active changes after third archive.
  - `xxx_docs/generated/workflow-metrics-weekly.md` generated with 100% success rate in the current 7-day sample.
- Remediation performed during validation:
  - Fixed typed-lint parser setup in `eslint.config.js`.
  - Fixed app demo startup entry path to `dist/src/server.js`.
  - Hardened PowerShell verify scripts to fail fast on non-zero command exit codes.
  - Fixed telemetry object mutation and metrics script strict-mode counting bugs.
