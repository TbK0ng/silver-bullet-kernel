## Context

The project must prioritize Codex usage while remaining compatible with Claude Code for collaboration. Trellis provides execution harness capabilities (spec injection, workflows, worktree policy), while OpenSpec provides artifact-driven change lifecycle and requirement traceability.

## Goals / Non-Goals

**Goals:**

- Deliver a usable implementation, not only methodology.
- Keep one clear source of truth per concern:
  - Trellis: execution policy
  - OpenSpec: change artifacts and requirements
- Enforce deterministic completion using verify scripts and CI.
- Provide an app-level demo that can be tested end-to-end.
- Produce full operational docs in `docs/`.

**Non-Goals:**

- Implementing advanced production concerns beyond workflow proof (auth, persistence, distributed infra).
- Replacing Trellis/OpenSpec internals.
- Supporting every AI runtime equally in v0.1.

## Decisions

- Use local Trellis source CLI for initialization because npm `@latest` lagged and missed `--codex`.
- Keep both Trellis and OpenSpec skills in `.codex/skills` to avoid capability loss after dual initialization.
- Use PowerShell verify scripts because the working environment is Windows-first.
- Use a minimal Express + TypeScript demo API for clear and fast usability proof.
- Keep docs in `docs/` as project-owned operational knowledge outside upstream Trellis docs.

## Risks / Trade-offs

- Running both frameworks can create command/skill overlap. Mitigated by role separation (Trellis for execution, OpenSpec for artifacts).
- Strict validation adds ceremony. Mitigated by `verify:fast` for quick local loops.
- Demo app without persistent storage is not full production. Accepted for workflow proof scope.
