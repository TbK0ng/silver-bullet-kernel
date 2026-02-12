# Troubleshooting

## `trellis init --codex` Not Recognized

Cause:

- npm release can lag behind repository main branch.

Fix:

- Use local built CLI from cloned Trellis source:
  - `node <trellis-repo>/dist/cli/index.js init --codex --claude -y -u <name>`

## OpenSpec Commands Not Found in Runtime

Cause:

- runtime or IDE needs restart after `openspec init` or `openspec update`.

Fix:

- restart runtime session
- verify command/skill files exist in `.claude/` or `.codex/skills/`

## CI Fails on OpenSpec Validation

Cause:

- missing or malformed artifacts in `openspec/`.

Fix:

- run `openspec validate --all --strict --no-interactive`
- repair invalid proposal/spec/task structure

## Verify Script Fails Locally but CI Passes

Cause:

- local stale dependencies or shell differences.

Fix:

- remove `node_modules`, run `npm install`
- re-run `npm run verify:ci` locally

## Workflow Policy Gate Fails

Cause:

- implementation edits exist but no active OpenSpec change or incomplete change artifacts.

Fix:

- create/continue change: `openspec new change <name>`
- ensure `proposal.md`, `design.md`, `tasks.md`, and spec deltas exist
- re-run `npm run workflow:policy`

## Indicator Gate Fails on Drift or Rework

Cause:

- metrics thresholds in `workflow-policy.json` are exceeded.

Fix:

- inspect `xxx_docs/generated/workflow-indicator-gate.md`
- remediate top failing indicators (drift backfill, rework reduction, WIP limit)
- regenerate metrics with `npm run metrics:collect`

## Token Cost Shows Unavailable

Cause:

- `.metrics/token-cost.json` has not been published.

Fix:

- publish summary:
  - `npm run metrics:token-cost -- -Source manual -TotalCostUsd 0`
- rerun:
  - `npm run metrics:collect`
  - `npm run workflow:gate`
