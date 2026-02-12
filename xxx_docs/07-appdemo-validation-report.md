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
  - `npm run demo:smoke` passed with `health=ok` and `count=1`.
  - `npm run verify:ci` passed including strict OpenSpec validation.
  - `openspec status --change bootstrap-codex-workflow-kernel` reached `4/4 artifacts complete` before archive.
  - `openspec archive bootstrap-codex-workflow-kernel -y` succeeded and merged delta specs.
  - `openspec validate --all --strict --no-interactive` passed for canonical specs.
- Remediation performed during validation:
  - Fixed typed-lint parser setup in `eslint.config.js`.
  - Fixed app demo startup entry path to `dist/src/server.js`.
  - Hardened PowerShell verify scripts to fail fast on non-zero command exit codes.
