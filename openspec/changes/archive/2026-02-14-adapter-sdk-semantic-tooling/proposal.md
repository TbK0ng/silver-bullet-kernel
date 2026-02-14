## Why

SBK now supports multiple adapters, but adapter extension still requires direct core edits and semantic tooling is primarily TypeScript-focused. To reach platform-level strength, we need a formal adapter SDK and cross-language semantic tool contracts.

## What Changes

- Define adapter SDK contract for third-party adapter plugins.
- Add `sbk adapter` command set for plugin registration, validation, and diagnostics.
- Add semantic tooling contracts for Python, Go, Java, and Rust refactors.
- Introduce capability checks ensuring semantic operations are deterministic and auditable.

## Capabilities

### New Capabilities
- `adapter-sdk-system`: plugin-style adapter lifecycle and validation.
- `semantic-tooling-multi-language`: deterministic refactor and symbol operations across major ecosystems.

### Modified Capabilities
- `codex-workflow-kernel`: extend runtime contract with adapter SDK management and semantic tooling surface.

## Impact

- Affected code: runtime scripts, adapter config schema, docs, and multi-language e2e tests.
- Operational impact: adapter ecosystem can scale without core churn, and refactor reliability improves across languages.
