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
- branch naming or owner mapping violates strict policy.
- local implementation is running in main worktree instead of linked worktree.

Fix:

- create/continue change: `openspec new change <name>`
- ensure `proposal.md`, `design.md`, `tasks.md`, and spec deltas exist
- use compliant branch name: `sbk-<owner>-<change>`
- run in linked worktree:
  - `git worktree add ..\\trellis-worktrees\\sbk-<owner>-<change> sbk-<owner>-<change>`
- re-run `npm run workflow:policy`

## CI Policy Gate Fails: Base Ref Unavailable

Cause:

- `WORKFLOW_BASE_REF` missing or remote base branch not fetched.

Fix:

- ensure CI step sets `WORKFLOW_BASE_REF` (for PR: `origin/<base_ref>`, for push: `origin/main`)
- ensure checkout fetches full history (`fetch-depth: 0`)

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
