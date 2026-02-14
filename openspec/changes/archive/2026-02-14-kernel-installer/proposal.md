## Why

SBK currently provides adapter-aware runtime and greenfield bootstrap, but there is no first-class command to install or upgrade the kernel into other repositories. Teams need a deterministic distribution mechanism to attach SBK to new or existing repos without manual file copying.

## What Changes

- Add `sbk install` command to copy SBK kernel files into a target repository.
- Add `sbk upgrade` command as overwrite-enabled installer mode for kernel refresh.
- Add preset-based copy policy (`minimal` and `full`) to control install surface.
- Add deterministic package script injection for installed verify/policy/doctor entrypoints.
- Add regression tests for install, idempotent rerun, and upgrade overwrite semantics.
- Update docs with install/upgrade runbook and preset guidance.

## Capabilities

### Modified Capabilities
- `codex-workflow-kernel`: extend runtime command contract with target-repo install and upgrade operations.

## Impact

- Affected code: `scripts/sbk.ps1`, new `scripts/sbk-install.ps1`, docs updates in `docs/02-*`, `docs/05-*`, `docs/06-*`, and new e2e tests.
- Operational impact: contributors can bootstrap and refresh SBK in arbitrary repos using one deterministic command contract.
