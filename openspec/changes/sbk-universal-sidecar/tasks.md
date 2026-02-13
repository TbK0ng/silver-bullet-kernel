## 1. OpenSpec and Configuration Baseline

- [x] 1.1 Define adapter/runtime/docs-sync requirements in proposal, design, and spec deltas.
- [x] 1.2 Add adapter manifests and sbk runtime config schema with strict-default behavior.

## 2. Runtime Implementation

- [x] 2.1 Implement shared runtime resolution helper for target root, adapter detection, and command matrix.
- [x] 2.2 Add `sbk` command dispatcher script with verify/policy/doctor/change/session routing.
- [x] 2.3 Update verify scripts to execute adapter-resolved command sequences while preserving telemetry.
- [x] 2.4 Update workflow policy gate to consume adapter-provided implementation path rules.

## 3. Governance and Tests

- [x] 3.1 Add docs sync gate script and wire it into verify entrypoints.
- [x] 3.2 Add e2e coverage for adapter override behavior and docs sync gate pass/fail paths.

## 4. Documentation and Evidence

- [x] 4.1 Update existing docs and add a dedicated multi-project onboarding guide with `sbk` command runbook.
- [x] 4.2 Update task evidence rows and validate change with targeted tests/verification commands.

## 5. Claude/Codex Parity Hardening

- [x] 5.1 Add runtime platform capability matrix and expose `sbk capabilities` command.
- [x] 5.2 Add skill parity gate and wire it into verify pipeline and workflow doctor.
- [x] 5.3 Support codex manual mode in Trellis multi-agent start/status flow.
- [x] 5.4 Align skill/command distribution surfaces across `.codex`, `.agents`, and `.claude`.
- [x] 5.5 Add e2e coverage for skill parity gate and codex manual multi-agent start.

## 6. Trellis Feature Completion and Entrypoint Hardening

- [x] 6.1 Extend OpenSpec artifacts for missing Trellis-derived feature scope and acceptance evidence.
- [x] 6.2 Add `sbk` subcommands for `explore`, `improve-ut`, `migrate-specs`, and `parallel` with Python runtime fallback.
- [x] 6.3 Extend multi-agent planning flow to include codex manual-mode support parity with start/status.
- [x] 6.4 Backfill missing workflow command/skill assets (`brainstorm`, `improve-ut`, `migrate-specs`) across `.codex`, `.agents`, and `.claude`.
- [x] 6.5 Backfill missing Trellis spec documents under `.trellis/spec/backend`, `.trellis/spec/guides`, and `.trellis/spec/unit-test`, including index wiring.
- [x] 6.6 Update docs runbooks for new `sbk` workflows and validate with targeted tests and gates.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/sbk-universal-sidecar/proposal.md`, `openspec/changes/sbk-universal-sidecar/design.md`, `openspec/changes/sbk-universal-sidecar/specs/*/spec.md`, `openspec/changes/sbk-universal-sidecar/tasks.md` | Define full OpenSpec contract for adapter runtime, docs sync gate, and command entrypoint. | `openspec validate sbk-universal-sidecar --type change --strict --json --no-interactive` | New change artifacts are complete and strict validation passes. |
| 1.2 | [x] | `sbk.config.json`, `config/adapters/node-ts.json`, `config/adapters/python.json`, `config/adapters/rust.json` | Add strict-default runtime config and built-in adapter manifests (Node/Python/Go/Java/Rust). | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Runtime config and adapter manifests are parsed and consumed by gates. |
| 2.1 | [x] | `scripts/common/sbk-runtime.ps1`, `workflow-policy.json` | Implement shared runtime resolver with adapter detect/override, profile overrides, and verify matrix export. | `npm run test:e2e -- tests/e2e/workflow-policy-gate.e2e.test.ts` | Adapter override behavior is validated by policy gate e2e test. |
| 2.2 | [x] | `scripts/sbk.ps1`, `package.json` | Add unified `sbk` dispatcher and expose npm entry (`npm run sbk -- <subcommand>`). | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1`, `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1 docs-sync -Mode local -NoReport -Quiet` | `sbk` command usage and docs-sync subcommand execution work end-to-end. |
| 2.3 | [x] | `scripts/verify-fast.ps1`, `scripts/verify.ps1`, `scripts/verify-ci.ps1`, `scripts/verify-loop.ps1` | Refactor verify entrypoints to use adapter command matrices while preserving telemetry and bounded diagnostics loop. | `npm run test:e2e -- tests/e2e/workflow-policy-gate.e2e.test.ts tests/e2e/workflow-docs-sync-gate.e2e.test.ts` | Verify pipeline changes are covered by e2e and telemetry paths remain intact. |
| 2.4 | [x] | `scripts/workflow-policy-gate.ps1`, `scripts/common/sbk-runtime.ps1`, `workflow-policy.json` | Make policy gate consume adapter implementation paths, profile overrides, and UTF-8-safe git path parsing. | `npm run test:e2e -- tests/e2e/workflow-policy-gate.e2e.test.ts` | Policy gate runtime and adapter override behavior are covered by passing e2e checks. |
| 3.1 | [x] | `scripts/workflow-docs-sync-gate.ps1`, `scripts/workflow-doctor.ps1`, `scripts/verify-fast.ps1`, `scripts/verify-ci.ps1` | Implement docs sync gate and wire it into verify and doctor health checks. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Runtime-doc drift now has deterministic gate and diagnostics visibility. |
| 3.2 | [x] | `tests/e2e/workflow-docs-sync-gate.e2e.test.ts`, `tests/e2e/workflow-policy-gate.e2e.test.ts` | Add pass/fail docs-sync e2e coverage and adapter override regression coverage. | `npm run test:e2e -- tests/e2e/workflow-policy-gate.e2e.test.ts tests/e2e/workflow-docs-sync-gate.e2e.test.ts` | New governance behavior is guarded by e2e regression tests. |
| 4.1 | [x] | `docs/README.md`, `docs/02-功能手册-命令原理与产物.md`, `docs/05-命令与产物速查表.md`, `docs/06-多项目类型接入与配置指南.md` | Sync docs with `sbk` command, adapters, docs-sync gate, and multi-project onboarding workflow. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Required runtime docs are updated and indexed. |
| 4.2 | [x] | `openspec/changes/sbk-universal-sidecar/tasks.md` | Finalize task evidence and run strict OpenSpec plus lint/e2e validation commands. | `openspec validate --all --strict --no-interactive`, `npm run lint`, `npm run test:e2e -- tests/e2e/workflow-policy-gate.e2e.test.ts tests/e2e/workflow-docs-sync-gate.e2e.test.ts` | Change evidence is complete with reproducible validation commands. |
| 5.1 | [x] | `config/platform-capabilities.json`, `scripts/common/sbk-runtime.ps1`, `scripts/sbk.ps1` | Add runtime platform capability matrix and expose `sbk capabilities` command output. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1 capabilities` | Runtime can print selected platform and capability parity matrix deterministically. |
| 5.2 | [x] | `scripts/workflow-skill-parity-gate.ps1`, `scripts/verify*.ps1`, `scripts/workflow-doctor.ps1`, `package.json` | Add skill parity gate and integrate into fast/full/ci verify and doctor checks. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-skill-parity-gate.ps1`, `npm run verify:fast` | Capability drift between Codex/Claude distribution surfaces now blocks verification. |
| 5.3 | [x] | `.trellis/scripts/common/cli_adapter.py`, `.trellis/scripts/multi_agent/start.py`, `.trellis/scripts/multi_agent/status.py` | Implement codex manual mode for multi-agent start/status while preserving worktree/context/registry lifecycle. | `npm run test:e2e -- tests/e2e/multi-agent-codex-manual.e2e.test.ts` | Codex multi-agent flow runs without CLI session/resume dependency and stays observable. |
| 5.4 | [x] | `.agents/skills/**`, `.codex/skills/**`, `.claude/skills/**`, `.claude/commands/trellis/*.md` | Align skill/command capability sets across codex/agents/claude surfaces with explicit mappings. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-skill-parity-gate.ps1` | Mirrors and command mappings satisfy parity gate checks. |
| 5.5 | [x] | `tests/e2e/workflow-skill-parity-gate.e2e.test.ts`, `tests/e2e/multi-agent-codex-manual.e2e.test.ts` | Add regression coverage for parity gate fail/pass cases and codex manual start behavior. | `npm run test:e2e -- tests/e2e/workflow-skill-parity-gate.e2e.test.ts tests/e2e/multi-agent-codex-manual.e2e.test.ts` | New parity and manual-mode contracts are covered by automated tests. |
| 6.1 | [x] | `openspec/changes/sbk-universal-sidecar/proposal.md`, `openspec/changes/sbk-universal-sidecar/design.md`, `openspec/changes/sbk-universal-sidecar/specs/*/spec.md`, `openspec/changes/sbk-universal-sidecar/tasks.md` | Extend change artifacts with Trellis feature completion scope and explicit acceptance criteria. | `openspec validate sbk-universal-sidecar --type change --strict --json --no-interactive` | Artifact chain remains strict-valid with new completion scope. |
| 6.2 | [x] | `scripts/sbk.ps1`, `scripts/openspec-explore.ps1`, `scripts/workflow-improve-ut.ps1`, `scripts/openspec-migrate-specs.ps1` | Add `sbk` advanced workflow subcommands and robust Python runtime fallback for delegated scripts. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1`, `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1 parallel --help`, `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1 improve-ut --skip-validation` | Unified entrypoint executes advanced workflows without environment-specific breakage. |
| 6.3 | [x] | `.trellis/scripts/multi_agent/plan.py`, `tests/e2e/multi-agent-codex-manual.e2e.test.ts` | Bring codex parity to multi-agent plan path with explicit manual-mode behavior. | `uv run python .trellis/scripts/multi_agent/plan.py --help`, `npm run test:e2e -- tests/e2e/multi-agent-codex-manual.e2e.test.ts` | Plan flow no longer excludes codex platform and preserves manual-mode semantics. |
| 6.4 | [x] | `.claude/commands/trellis/`, `.codex/skills/`, `.agents/skills/`, `.claude/skills/` | Backfill missing Trellis workflow assets and keep Codex/Claude/Agents capability surfaces aligned. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-skill-parity-gate.ps1` | Skill/command parity gate passes after asset completion. |
| 6.5 | [x] | `.trellis/spec/backend/`, `.trellis/spec/guides/`, `.trellis/spec/unit-test/`, `.trellis/spec/*/index.md` | Restore missing Trellis specs used by workflow commands and testing conventions. | `rg -n \"cross-platform-thinking-guide|script-conventions|unit-test\" .trellis/spec` | Spec references used by commands/skills resolve to real files and index links. |
| 6.6 | [x] | `docs/02-功能手册-命令原理与产物.md`, `docs/06-多项目类型接入与配置指南.md`, `tests/e2e/workflow-skill-parity-gate.e2e.test.ts`, `tests/e2e/multi-agent-codex-manual.e2e.test.ts` | Update runbooks for new `sbk` command surface and validate with targeted tests/gates. | `npm run test:e2e -- tests/e2e/workflow-skill-parity-gate.e2e.test.ts tests/e2e/multi-agent-codex-manual.e2e.test.ts`, `npm run sbk -- skill-parity` | Docs and tests reflect feature-complete command surface and parity guarantees. |
