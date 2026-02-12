## Context

Current governance enforces branch naming, owner mapping, and linked worktree usage, but still allows CI branch-delta blind spots on `push main` and lacks hard checks for task evidence schema and deterministic semantic refactor workflows.

## Goals

1. Ensure CI branch-delta input is always meaningful and fail-closed.
2. Ensure active change tasks are executable evidence artifacts, not free-form placeholders.
3. Provide deterministic, reusable execution tools for:
   - verify/fix loops
   - semantic symbol rename

## Non-Goals

- Replacing OpenSpec lifecycle commands.
- Building a full multi-language LSP platform in this change.
- Auto-fixing arbitrary failures in CI.

## Decisions

### Decision 1: CI base ref must never collapse to current HEAD

- CI push workflow provides `WORKFLOW_BASE_REF=${{ github.event.before }}`.
- Policy gate explicitly fails when resolved base ref equals `HEAD` in CI mode.

### Decision 2: Tasks evidence schema is a hard gate

- For each active change, `tasks.md` must include a Markdown table header with columns:
  - `Files`
  - `Action`
  - `Verify`
  - `Done`
- Missing schema fails policy gate.

### Decision 3: Verify/fix loop is explicit command surface

- Add `scripts/verify-loop.ps1` with bounded retries.
- On each failure, run diagnostics and persist loop evidence under `.metrics/verify-fix-loop.jsonl`.
- Keep deterministic behavior (no opaque autonomous edits).

### Decision 4: Semantic rename uses TypeScript compiler API

- Add `scripts/semantic-rename.ts` for symbol rename by file/line/column.
- Expose via npm script and Codex skill runbook.
- This provides AST-level determinism for refactor operations.

## Risks and Mitigations

- Risk: Stricter tasks schema blocks teams with legacy task formats.
  - Mitigation: clear remediation text and docs update.
- Risk: Semantic rename command misuse by wrong cursor location.
  - Mitigation: dry-run support and validation that symbol exists.
- Risk: Verify loop increases local runtime.
  - Mitigation: bounded retries and optional use (does not replace fast gate).

