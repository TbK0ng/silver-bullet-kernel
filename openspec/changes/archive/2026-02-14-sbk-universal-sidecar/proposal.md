## Why

Silver Bullet Kernel currently assumes a repository-local Node/TypeScript workflow and does not provide a stable single-command entrypoint for heterogeneous greenfield projects. We need a target-aware tool mode so SBK can be attached to new projects (Node, Python, Go, Java, Rust) without polluting business code structure while preserving strict governance behavior.

## What Changes

- Add a unified `sbk` command entrypoint that dispatches verify/policy/doctor/change/session operations.
- Add `sbk capabilities` to publish platform capability matrix and selected runtime platform.
- Add `sbk` workflow subcommands for explore/improve-ut/migrate-specs/parallel so Trellis planning, testing, and spec-sync operations are accessible from one runtime entry.
- Introduce adapter-based project targeting with built-in profiles for Node/TypeScript, Python, Go, Java, and Rust.
- Make policy/verify scripts target-aware via adapter configuration instead of hard-coded implementation paths and command matrix.
- Add skill/command parity gate so Claude/Codex distribution surfaces stay aligned.
- Add a docs sync gate that fails workflow verification when runtime/tooling contract changes are not reflected in `docs/`.
- Add Codex manual multi-agent mode so worktree/task orchestration remains complete even without CLI session controls.
- Backfill Trellis-derived capability docs and guides (`.trellis/spec/backend/*`, `.trellis/spec/guides/*`, `.trellis/spec/unit-test/*`) required by new command/skill workflows.
- Add and update runbooks for universal project onboarding and `sbk` command usage.

## Capabilities

### New Capabilities
- `sbk-multi-project-adapters`: Adapter-based project detection and target-aware command/policy orchestration.
- `workflow-docs-sync-gate`: Deterministic documentation synchronization checks for workflow/runtime contract changes.
- `workflow-skill-parity-gate`: Deterministic capability parity checks across `.codex`, `.agents`, and `.claude` distribution surfaces.

### Modified Capabilities
- `codex-workflow-kernel`: Extend kernel runtime contract to include unified `sbk` entrypoint and adapter-driven verify/policy behavior.
- `codex-workflow-kernel`: Add platform capability matrix contract and codex manual-mode multi-agent support.
- `workflow-docs-system`: Extend docs requirements to cover cross-ecosystem onboarding and docs sync gate operation.

## Impact

- Affected code: `scripts/*.ps1`, `scripts/common/*.ps1`, `.trellis/scripts/multi_agent/*.py`, `.claude/commands/trellis/*.md`, `.{codex,agents,claude}/skills/**`, `workflow-policy.json`, `package.json`, `tests/e2e/*.test.ts`, and `docs/*.md`.
- New configuration surface: adapter manifests and sbk runtime config.
- Operational impact: Contributors can bootstrap SBK into non-TS projects with one command contract while keeping strict governance and traceability, while Claude/Codex workflow features remain symmetric and configurable.
