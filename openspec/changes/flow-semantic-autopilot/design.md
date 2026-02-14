## Context

We need a practical automation layer that removes command-chaining overhead while preserving explicit governance and deterministic outputs.

## Goals / Non-Goals

**Goals**
- Provide one top-level command to run onboarding/hardening flow.
- Keep key decisions controllable: auto-decide or interactive choose.
- Enable full semantic operation surface without hidden fail-open behavior.
- Make strict intake readiness gate enabled by default.

**Non-Goals**
- Replace existing command families.
- Depend on heavyweight language server bootstrapping for default operation.
- Remove fail-closed guardrails when deterministic behavior cannot be guaranteed.

## Decisions

### Decision 1: Introduce orchestration command family
Add `sbk flow run` to orchestrate greenfield or brownfield flows.

Key decision nodes:
- scenario (`greenfield|brownfield|auto`)
- adapter
- profile
- blueprint pack
- release channel

Decision modes:
- `auto`: resolve via deterministic heuristics and existing runtime config.
- `ask`: prompt operator at unresolved key nodes.

### Decision 2: Keep orchestration built on existing commands
`sbk flow run` invokes existing command contracts (`greenfield`, `blueprint`, `intake`, `adapter doctor`, optional verify/fleet) instead of duplicating business logic.

### Decision 3: Enable semantic operation completeness
Enable `reference-map` and `safe-delete-candidates` operations through deterministic backends.

- Node/TS: TypeScript language-service backend.
- Python: token/AST-backed deterministic backend.
- Go/Java/Rust: deterministic symbol-index backend.

### Decision 4: Enable strict intake readiness by default
Set `workflow-policy.intakeGate.requireStrictReadinessArtifact=true` so strict profile verification enforces readiness artifacts unless explicitly overridden.

## Risks / Trade-offs

- [Risk] One-command flow can hide details from advanced users.
  - Mitigation: keep stage logs, summary report artifact, and explicit decision traces.
- [Risk] Symbol-index semantic backend is conservative.
  - Mitigation: deterministic output contract and clear remediation for unsupported complex cases.
- [Risk] Enabling strict readiness by default can increase initial failures.
  - Mitigation: orchestration automatically generates required intake artifacts before strict verify.

## Migration Plan

1. Add `sbk flow` entry and orchestration script.
2. Enable semantic operations and multi-language deterministic backends.
3. Update policy default and adapter capability declarations.
4. Add/adjust e2e coverage and docs.
