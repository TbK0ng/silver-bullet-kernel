## Context

Users adopting SBK outside this repository need predictable installation and upgrade behavior. Manual copy steps are error-prone, and incomplete copy state can break verify/policy gates.

## Goals / Non-Goals

**Goals**
- Provide one command for initial install and one command for upgrade.
- Support target repository path and preset selection.
- Keep install idempotent by default; allow explicit overwrite for upgrade.
- Inject missing npm scripts when a target `package.json` exists.

**Non-Goals**
- Auto-install Node/Python/OpenSpec toolchains.
- Replace project-specific verify command matrices.
- Manage git remotes/submodules in target repositories.

## Decisions

### Decision 1: `sbk install` and `sbk upgrade` are routed via `scripts/sbk.ps1`
`sbk install` performs safe copy (skip existing by default).  
`sbk upgrade` reuses installer logic with overwrite enabled.

Rationale: keeps user-facing contract simple while preserving one implementation path.

### Decision 2: Preset-based file selection
Support two presets:
- `minimal`: strict core governance/runtime files.
- `full`: extended runtime package (scripts/config/docs/specs/skills).

Rationale: users can choose low-friction adoption or full feature surface.

### Decision 3: Explicit include lists, not broad repo copy
Installer uses curated include sets and excludes volatile/runtime directories (`node_modules`, `.git`, `.metrics`, `.trellis/workspace`, `trellis-worktrees`).

Rationale: avoid copying local state and unrelated artifacts.

### Decision 4: Script injection is additive and conditional
If target has `package.json`, missing scripts are added only when corresponding script files exist.

Rationale: non-destructive behavior keeps existing package scripts stable.

## Risks / Trade-offs

- [Risk] Full preset can still be larger than some projects expect.
  - Mitigation: default users can choose `minimal`.
- [Risk] Copying docs/skills may drift if new files are added but include list is not updated.
  - Mitigation: use directory-level includes for stable modules and document preset scope.
- [Risk] Overwrite mode can replace local target customizations.
  - Mitigation: keep install default safe; make overwrite explicit (`upgrade` or `--overwrite`).

## Migration Plan

1. Add installer script with preset file collection and package script injection.
2. Add `sbk install` / `sbk upgrade` routing and help text.
3. Add e2e coverage for install/idempotent/upgrade behavior.
4. Update docs for installer command contract and adoption flow.

Rollback:
- Remove new subcommands and installer script; existing runtime commands remain unchanged.
