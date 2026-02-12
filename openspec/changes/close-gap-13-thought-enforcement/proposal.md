## Why

The workflow kernel already enforces strict branch/worktree governance, but three gaps still weaken the target philosophy:

1. CI `push main` can evaluate branch delta against `origin/main` (same HEAD), producing empty implementation deltas and reducing governance signal quality.
2. OpenSpec task evidence format (`Files/Action/Verify/Done`) is documented but not enforced mechanically.
3. Deterministic execution improvements from related projects (Ralph/OMC verify loop, oh-my-opencode LSP/AST tooling) are not yet codified in the Codex-first path.

To align with the silver-bullet plan sections 1-3, these rules must move from guidance into enforceable policy and executable tooling.

## What Changes

- Harden CI branch-delta evaluation:
  - use push event base commit (`github.event.before`) as `WORKFLOW_BASE_REF`.
  - fail policy gate if base ref resolves to current HEAD in CI.
- Add active-change task evidence schema enforcement:
  - `tasks.md` must include `Files`, `Action`, `Verify`, `Done` columns.
- Add deterministic verify/fix loop entry point:
  - implement retry loop script with mandatory diagnostics artifact generation.
- Add semantic refactor command:
  - TypeScript semantic rename command (AST/LSP-style symbol rename) and Codex skill runbook.
- Update docs, specs, and troubleshooting guidance for the new hard constraints.

## Impact

- Affected specs:
  - `codex-workflow-kernel`
  - `memory-governance-policy`
  - `workflow-docs-system`
- Affected systems:
  - CI workflow wiring
  - policy gate script and config
  - verify command surface
  - Codex skills and operator docs

