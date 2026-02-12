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
