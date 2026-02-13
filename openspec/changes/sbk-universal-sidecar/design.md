## Context

SBK already enforces policy-as-code, OpenSpec traceability, and worktree/session governance for this repository, but the runtime contract is still tightly coupled to a fixed command matrix (`npm run lint/typecheck/test/build`) and fixed implementation paths. Teams onboarding SBK to new projects need a stable entrypoint (`sbk`) and adapter-driven behavior that preserves governance while minimizing codebase pollution.

## Goals / Non-Goals

**Goals:**
- Provide a single `sbk` command entrypoint for core operations.
- Add first-class adapters for Node/TS, Python, Go, Java, Rust.
- Keep strict governance rules intact by default.
- Allow configuration overrides through explicit runtime config files.
- Enforce docs updates whenever workflow/runtime contracts change.

**Non-Goals:**
- Replace OpenSpec with a different planning system.
- Implement ecosystem-specific deep lint plugins beyond command matrix orchestration.
- Auto-install language toolchains.

## Decisions

### Decision 1: Adapter manifests define implementation scope + verify matrix
Use JSON manifests per ecosystem to define:
- detection markers
- implementation path prefixes/files
- verify commands for `fast`/`full`/`ci`

Rationale: keeps policy and verify behavior configurable and composable without hard-coding per-project logic in scripts.

Alternative considered: inline adapter logic directly in `verify*.ps1` and `workflow-policy-gate.ps1`. Rejected because it grows brittle and difficult to evolve.

### Decision 2: `sbk` PowerShell command as canonical dispatcher
Introduce `scripts/sbk.ps1` as the command router for init/verify/policy/doctor/change/session actions.

Rationale: aligns with current repository runtime and avoids introducing a second orchestration runtime.

Alternative considered: Node-based CLI binary only. Rejected for now because the existing script stack is PowerShell-first and would require dual parity maintenance.

### Decision 3: Target-aware helper module shared by verify/policy scripts
Create a shared module under `scripts/common/` to resolve:
- target repo root
- adapter selection (`auto` or explicit)
- command matrix
- implementation path overrides

Rationale: single source of truth for runtime targeting decisions.

### Decision 4: Docs sync gate as policy check, not advisory check
Add deterministic gate (`scripts/workflow-docs-sync-gate.ps1`) and integrate it into verify flow.

Rationale: user requirement explicitly demands implementation/docs synchronization.

## Risks / Trade-offs

- [Risk] Adapter auto-detect may pick wrong ecosystem in mixed-language repos.
  - Mitigation: explicit adapter override in config.
- [Risk] New verify matrix may break existing repo defaults.
  - Mitigation: keep `node-ts` default with backward-compatible commands.
- [Risk] Docs sync heuristics can produce false positives.
  - Mitigation: constrain trigger paths and required docs map; keep mapping declarative.

## Migration Plan

1. Add adapter/config/helper layer with backward-compatible defaults.
2. Update policy/verify scripts to consume helper outputs.
3. Add `sbk` dispatcher command.
4. Add docs sync gate and wire into verify flow.
5. Update docs and quick reference.
6. Add/adjust e2e tests for adapter override and docs sync gate behavior.

Rollback strategy:
- Revert to previous verify/policy scripts and remove adapter wiring while keeping OpenSpec artifacts untouched.

## Open Questions

- Should a future release add a cross-platform shell wrapper (`sbk` bash shim) in addition to PowerShell?
- Should docs sync mapping eventually move into `workflow-policy.json` for centralized policy management?
