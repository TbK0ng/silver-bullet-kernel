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
