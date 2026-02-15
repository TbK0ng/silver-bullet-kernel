## Why

Current SBK capabilities are strong but still fragmented at execution time: contributors must manually chain commands, two semantic operations are fail-closed placeholders, and strict intake readiness is not enforced by default.

## What Changes

- Add a one-command orchestration entry (`sbk flow run`) that executes end-to-end greenfield or brownfield flows.
- Add decision-mode support for key runtime nodes (`auto` heuristics vs interactive `ask`).
- Enable semantic `reference-map` and `safe-delete-candidates` operations.
- Add deterministic semantic backend support for Go/Java/Rust (no fail-closed placeholder for standard workflows).
- Enable strict intake readiness policy by default.

## Capabilities

### Modified Capabilities
- `codex-workflow-kernel`: add one-command orchestration and decision-node control.
- `semantic-tooling-multi-language`: enable complete operation surface (rename/reference-map/safe-delete) across supported adapters.

## Impact

- Affected code: `scripts/sbk.ps1`, new `scripts/sbk-flow.ps1`, `scripts/sbk-semantic.ps1`, semantic backend scripts, adapter manifests, policy config, docs, and e2e tests.
- Operational impact: teams can execute robust onboarding/hardening in one command while preserving deterministic governance.
