## Context

The current documentation set mixes three different concepts:
- command-level trigger semantics
- AI-assisted execution delegation
- workflow recommendations

When these are not separated, contributors misread:
- conditional stage execution as unconditional behavior
- explicit commands as implicit behavior

Runtime behavior in `scripts/sbk-flow.ps1` and `scripts/sbk.ps1` is deterministic and already supports clear boundaries. This change is documentation and spec-contract alignment, not implementation redesign.

## Goals / Non-Goals

**Goals**
- Make trigger semantics explicit across core docs and practice docs.
- Ensure runbooks distinguish explicit commands from conditional implicit stages.
- Ensure docs do not imply hidden command behavior because AI can run multi-step instructions.
- Normalize command examples for both generic (`sbk`) and repo-local (`npm run sbk --`) operator contexts.

**Non-Goals**
- No changes to flow orchestration code paths.
- No changes to policy gate logic.
- No changes to adapter/runtime configuration schema.

## Decisions

### Decision 1: Treat trigger semantics as a first-class documentation contract

Introduce and apply one shared framing across docs:
- **Explicit trigger**: a command/operator action that must be invoked directly.
- **Conditional implicit stage**: a stage that executes only when condition flags/context are met.
- **Not implicit**: clearly state what does *not* auto-run.

### Decision 2: Document `sbk flow run` using condition table semantics

Flow docs must include condition-bound stage behavior:
- `--with-install` controls install stage.
- `scenario` controls greenfield stage.
- `--skip-verify` controls verify-fast stage.
- `--fleet-roots` controls fleet stages.
- non-git target causes flow bootstrap `git init`.
- auto mode may profile-fallback strict -> balanced -> lite during intake verify.

### Decision 3: Separate AI delegation wording from command behavior wording

Prompt playbooks and "AI can auto execute" sections must explicitly state:
- AI may run multiple explicit commands for the user.
- This does not change command trigger semantics.

### Decision 4: Clarify explicit workflow lifecycle commands

Runbooks must explicitly call out:
- `sbk new-change` creates a change container only.
- `sbk explore` is explicit exploration entry, not an implicit stage in `flow run`.
- `/trellis:record-session` and `sbk record-session` are explicit session evidence actions.

### Decision 5: Classify high-risk switches as explicit trigger semantics

Docs and prompt playbooks must explicitly classify high-risk switches as opt-in triggers:
- `sbk flow run --force` (overwrite behavior)
- `sbk flow run --allow-beta` (beta asset allowance)
- `sbk migrate-specs --unsafe-overwrite` (unsafe full overwrite)

For `flow run`, docs must additionally clarify conditional interplay:
- `--channel beta` enables beta asset allowance semantics.
- blueprint force mode can occur under documented contexts (`--force`, `--with-install`, existing CI workflow file).

### Decision 6: Provide code-evidence trigger matrix as long-term baseline

Add a dedicated docs page that maps trigger rules to concrete script evidence (path + line):
- command dispatch evidence from `scripts/sbk.ps1`
- stage/condition evidence from `scripts/sbk-flow.ps1`
- high-risk switch evidence from blueprint/greenfield/migrate scripts

This page serves as the anti-drift baseline for future docs-sync maintenance.

## Risks / Trade-offs

- Risk: documentation drift reappears after future script updates.
  - Mitigation: consolidate semantics in core docs and mirror to practice docs; keep docs-sync coverage.
- Risk: increased wording verbosity.
  - Mitigation: concise semantics blocks and operator-facing examples.
- Risk: mixed command styles confuse readers.
  - Mitigation: explicit "generic vs repo-local equivalent" notes.
