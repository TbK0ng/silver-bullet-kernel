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
- `WORKFLOW_BASE_REF` resolves to current `HEAD` (degenerate delta context).

Fix:

- ensure CI step sets `WORKFLOW_BASE_REF` (for PR: `origin/<base_ref>`, for push: `${{ github.event.before }}`)
- ensure checkout fetches full history (`fetch-depth: 0`)

## Policy Gate Fails: Tasks Evidence Schema

Cause:

- active change `tasks.md` is missing strict evidence requirements (heading/columns/non-empty rows/granularity bounds).

Fix:

- use required heading and table format:
  - `### Task Evidence`
  - `| ID | Status | Files | Action | Verify | Done |`
- ensure at least one non-empty data row exists
- keep row granularity within policy (`maxFilesPerTaskRow`, `maxActionLength`)
- re-run `npm run workflow:policy`

## Policy Gate Fails: Session Disclosure Metadata

Cause:

- owner session evidence exists but required markers are missing.

Fix:

- add markers in `.trellis/workspace/<owner>/journal-*.md`:
  - `Memory Sources`
  - `Disclosure Level`
  - `Source IDs`
- re-run `npm run workflow:policy`

## Policy Gate Fails: Security Secret Scan

Cause:

- durable artifact contains a credential-like token pattern.

Fix:

- redact the token from affected file
- replace with safe placeholder (for example `<redacted>`)
- re-run `npm run workflow:policy`

## Policy Gate Fails: Dispatcher Orchestrator Boundary

Cause:

- `.claude/agents/dispatch.md` frontmatter includes forbidden write-capable tools.

Fix:

- keep dispatcher tools route/read-only
- remove forbidden tools (`Write`, `Edit`, `MultiEdit`)
- re-run `npm run workflow:policy`

## Repeated Local Verify Failures

Cause:

- failure recurs without structured diagnostics loop.

Fix:

- run bounded verify/fix loop:
  - `npm run verify:loop -- -Profile fast -MaxAttempts 2`
- inspect `.metrics/verify-fix-loop.jsonl` for failed attempts and diagnostics outcomes.

## Unsafe Text Replace Rename

Cause:

- symbol rename done by plain text replacement, causing semantic drift.

Fix:

- run semantic rename dry-run first:
  - `npm run refactor:rename -- --file <path> --line <n> --column <n> --newName <name> --dryRun`
- then apply rename and verify:
  - `npm run verify:fast`

## Indicator Gate Fails on Drift or Rework

Cause:

- metrics thresholds in `workflow-policy.json` are exceeded.

Fix:

- inspect `xxx_docs/generated/workflow-indicator-gate.md`
- remediate top failing indicators (drift backfill, rework reduction, WIP limit)
- regenerate metrics with `npm run metrics:collect`

## CI Indicator Looks Inconsistent with Local History

Cause:

- CI intentionally uses isolated telemetry path to avoid local history contamination.

Fix:

- trust CI `verify:ci` result for merge gating
- for trend analysis, use local weekly routine (`npm run metrics:collect` + `npm run workflow:gate`)

## Token Cost Shows Unavailable

Cause:

- `.metrics/token-cost.json` has not been published.

Fix:

- publish summary:
  - `npm run metrics:token-cost -- -Source manual -TotalCostUsd 0`
- rerun:
  - `npm run metrics:collect`
  - `npm run workflow:gate`
