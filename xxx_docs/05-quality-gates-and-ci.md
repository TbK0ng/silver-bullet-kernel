# Quality Gates and CI

## Gate Definitions

- Fast local: `npm run verify:fast`
- Full local: `npm run verify`
- CI strict: `npm run verify:ci`

## CI Behavior

GitHub Actions workflow at `.github/workflows/ci.yml`:

- installs dependencies
- installs OpenSpec CLI
- runs `scripts/verify-ci.ps1`

## Why Single Verify Entry Matters

Using one script for CI and local verification:

- reduces drift between local and CI
- makes failures reproducible
- makes task evidence objective

## Required Evidence in Change Tasks

- exact command(s) run
- pass/fail result
- if failed: root cause and fix path

## Telemetry

- Verify scripts append run telemetry to `.metrics/verify-runs.jsonl` (local only, gitignored).
- Weekly report generation:
  - `npm run metrics:collect`
  - outputs:
    - `xxx_docs/generated/workflow-metrics-weekly.md`
    - `xxx_docs/generated/workflow-metrics-latest.json`
