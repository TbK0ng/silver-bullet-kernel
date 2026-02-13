## Context

Greenfield onboarding needs two things before feature implementation begins:

1. Project-level planning artifacts that persist intent and progress.
2. Adapter-aligned starter files so verify/policy behavior can be configured predictably.

Current `sbk init` is aimed at brownfield guideline backfill and does not generate these artifacts.

## Goals / Non-Goals

**Goals**
- Provide one command to scaffold project-level planning artifacts for new repositories.
- Support language ecosystem selection via existing adapter names.
- Keep behavior safe by default (no overwrite without explicit force).
- Ensure generated output is deterministic and testable.

**Non-Goals**
- Generate production-ready business code.
- Auto-install language toolchains or dependencies.
- Replace OpenSpec artifact workflow with a different planning system.

## Decisions

### Decision 1: Add dedicated `sbk greenfield` subcommand
Route `sbk greenfield` from `scripts/sbk.ps1` to a focused bootstrap script.

Rationale: keeps brownfield `sbk init` semantics stable while adding an explicit greenfield path.

### Decision 2: Use deterministic file templates inside bootstrap script
Generate a fixed set of project-level artifacts:
- `PROJECT.md`
- `REQUIREMENTS.md`
- `ROADMAP.md`
- `STATE.md`
- `CONTEXT.md`
- `.planning/research/.gitkeep`

Rationale: these files capture product intent, boundaries, and execution state with minimal ceremony.

### Decision 3: Adapter-aware language stubs are optional and safe
Support `node-ts`, `python`, `go`, `java`, and `rust` starter stubs.
Default behavior writes only missing files. `--force` allows overwrite.

Rationale: avoids damaging existing work while still enabling true 0-to-1 bootstrap.

### Decision 4: Update runtime config when adapter is selected
When scaffolding runs with `--adapter`, create/update `sbk.config.json` to set adapter explicitly.

Rationale: avoids ambiguous auto-detect for greenfield repos with minimal files.

## Risks / Trade-offs

- [Risk] Starter stubs may not pass all ecosystem checks out of the box.
  - Mitigation: generated files include explicit "replace me" intent and docs call out next steps.
- [Risk] Overwrite mode could erase user edits.
  - Mitigation: overwrite is explicit via `--force`; default mode preserves existing files.
- [Risk] Command surface growth can drift from docs.
  - Mitigation: include docs updates and e2e checks in same change.

## Migration Plan

1. Add new bootstrap script.
2. Add `sbk greenfield` routing and help text.
3. Add e2e tests for generated artifacts and idempotency.
4. Update docs for greenfield onboarding flow.

Rollback:
- Remove `sbk greenfield` route and script; existing brownfield path remains unchanged.
