## 1. OpenSpec and Contract Baseline

- [x] 1.1 Define installer/upgrade runtime contract in proposal, design, and spec delta.

## 2. Runtime Implementation

- [x] 2.1 Add `sbk install` and `sbk upgrade` command routing and help text.
- [x] 2.2 Implement installer script with preset-based file selection and copy summaries.
- [x] 2.3 Implement package script injection and overwrite semantics.

## 3. Regression Coverage

- [x] 3.1 Add e2e tests for minimal/full install behavior.
- [x] 3.2 Add e2e tests for idempotent rerun and overwrite-enabled upgrade.

## 4. Documentation and Evidence

- [x] 4.1 Update docs/runbooks for install/upgrade command usage.
- [x] 4.2 Complete task evidence rows with verification outcomes.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/kernel-installer/proposal.md`, `openspec/changes/kernel-installer/design.md`, `openspec/changes/kernel-installer/tasks.md`, `openspec/changes/kernel-installer/specs/codex-workflow-kernel/spec.md` | Defined installer/upgrade runtime scope, preset contract, and acceptance scenarios. | `openspec validate kernel-installer --type change --strict --json --no-interactive` | Strict change validation passes with no issues. |
| 2.1 | [x] | `scripts/sbk.ps1` | Added `install` and `upgrade` subcommands with argument forwarding and help output. | `powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1` | `sbk` help shows install/upgrade command contracts. |
| 2.2 | [x] | `scripts/sbk-install.ps1` | Implemented preset-based file collection and copy summary reporting for target repos. | `npx vitest run tests/e2e/sbk-install.e2e.test.ts` | E2E validates minimal/full install file outputs. |
| 2.3 | [x] | `scripts/sbk-install.ps1` | Implemented additive package script injection and overwrite semantics for upgrade mode. | `npx vitest run tests/e2e/sbk-install.e2e.test.ts` | E2E validates non-overwrite install rerun and overwrite upgrade behavior. |
| 3.1 | [x] | `tests/e2e/sbk-install.e2e.test.ts` | Added coverage for minimal/full preset install behavior and package script injection. | `npx vitest run tests/e2e/sbk-install.e2e.test.ts` | New install test suite passes 4/4 scenarios. |
| 3.2 | [x] | `tests/e2e/sbk-install.e2e.test.ts` | Added idempotent rerun and overwrite-enabled upgrade regression coverage. | `npx vitest run tests/e2e/sbk-install.e2e.test.ts` | Installer regression covers safe rerun and upgrade overwrite paths. |
| 4.1 | [x] | `docs/02-功能手册-命令原理与产物.md`, `docs/05-命令与产物速查表.md`, `docs/06-多项目类型接入与配置指南.md` | Updated command handbook and onboarding runbook for install/upgrade adoption flow. | `powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local -NoReport -Quiet` | Docs sync gate passes after install/upgrade docs updates. |
| 4.2 | [x] | `openspec/changes/kernel-installer/tasks.md` | Finalized evidence rows with strict verification outcomes. | `openspec validate --all --strict --no-interactive` | All specs and changes validate strictly (12 passed, 0 failed). |
