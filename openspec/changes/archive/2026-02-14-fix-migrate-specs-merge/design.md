## Context

The existing migrate-specs script reads each delta `spec.md` file and writes it directly to `openspec/specs/<capability>/spec.md`. This bypasses OpenSpec delta semantics and can silently remove canonical requirements unrelated to the active change.

## Goals / Non-Goals

**Goals:**
- Make migration non-destructive by default.
- Apply delta intent at requirement/scenario granularity.
- Preserve idempotence for repeated apply runs.
- Keep an explicit escape hatch for full overwrite.

**Non-Goals:**
- Implement a generic Markdown AST engine.
- Auto-resolve semantic conflicts across multiple changes.

## Decisions

### Decision 1: Default to merge semantics
`migrate-specs --apply` will parse delta sections and update canonical specs incrementally rather than replacing whole files.

Rationale: aligns with OpenSpec delta intent and protects canonical history.

### Decision 2: Add explicit destructive mode
Introduce `--unsafe-overwrite` to preserve operational flexibility for exceptional recovery workflows.

Rationale: destructive behavior remains available but is explicit and auditable.

### Decision 3: Fail closed on ambiguous modifications
For `MODIFIED`, `REMOVED`, and unresolved `RENAMED` operations, fail when the target requirement cannot be found.

Rationale: avoid silent drift and make merge failures actionable.

### Decision 4: Regression-test merge and failure paths
Add e2e tests validating:
- canonical content is preserved during merge;
- repeated apply runs are stable;
- missing-target modifications fail.

Rationale: prevents regression to overwrite semantics.

## Risks / Trade-offs

- [Risk] Markdown parsing by regex may miss unusual formatting layouts.
  - Mitigation: enforce strict OpenSpec format assumptions and fail on unrecognized change structures.
- [Risk] Explicit overwrite mode can still be misused.
  - Mitigation: flag it as unsafe in docs and CLI help text.

## Migration Plan

1. Implement merge helpers and integrate into migrate-specs apply path.
2. Add `--unsafe-overwrite` routing at `sbk` entrypoint.
3. Add e2e regression tests.
4. Update documentation and validate OpenSpec artifacts.
