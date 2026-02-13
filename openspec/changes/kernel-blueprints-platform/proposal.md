## Why

Greenfield support is now available, but still too close to bootstrap-level scaffolding. To make SBK product-grade for zero-to-one delivery, we need reusable blueprint packs that generate deployable baselines with CI, security defaults, observability hooks, and architecture artifacts in one flow.

## What Changes

- Add blueprint packs for common project archetypes (API service, worker, CLI, monorepo service set).
- Introduce `sbk blueprint` command to scaffold production baselines from selected blueprint.
- Generate baseline operational files (CI workflow, env contract, release checklist, runbook skeleton).
- Generate architecture decision artifacts linked to OpenSpec change lifecycle.
- Add verification flow to assert generated baseline is internally coherent.

## Capabilities

### New Capabilities
- `workflow-blueprints-platform`: reusable, versioned blueprint system for greenfield projects.

### Modified Capabilities
- `codex-workflow-kernel`: extend command/runtime contract with blueprint orchestration.

## Impact

- Affected code: `scripts/`, `config/`, `docs/`, `openspec/specs/`, and e2e tests.
- Operational impact: teams can bootstrap publish-ready project baselines in a deterministic, policy-aligned way.
