## Why

Brownfield support currently assumes contributors can manually map architecture risk and onboarding complexity. For enterprise-grade adoption, SBK needs a deep intake engine that classifies risk, proposes staged governance upgrades, and auto-generates remediation plans before implementation starts.

## What Changes

- Add `sbk intake` workflow to perform deep brownfield analysis.
- Produce structured intake outputs: architecture map, risk tiers, dependency health, test maturity, blast-radius profile.
- Add staged governance recommendation (`lite -> balanced -> strict`) with explicit prerequisites.
- Add `sbk intake verify` to validate readiness for strict mode.

## Capabilities

### New Capabilities
- `brownfield-intake-engine`: deterministic brownfield onboarding and risk-hardening workflow.

### Modified Capabilities
- `codex-workflow-kernel`: extend onboarding contract with risk-classified intake and migration planning.

## Impact

- Affected code: intake scripts, policy integration points, docs, and e2e tests.
- Operational impact: teams can adopt SBK in large legacy repos with predictable risk management and phased enforcement.
