## Context

`sbk greenfield` currently creates planning artifacts and minimal language stubs. Product-grade greenfield adoption requires stronger baseline generation: repeatable architecture setup, CI/security defaults, operational runbooks, and deployment readiness checks.

## Goals / Non-Goals

**Goals**
- Provide blueprint-driven project generation for common archetypes.
- Include policy-aligned defaults from day zero (verify, doctor, security scan, docs sync).
- Produce architecture artifacts (`ADR`, service boundaries, dependency contract).
- Validate generated baseline with deterministic checks.

**Non-Goals**
- Deploy infrastructure to cloud providers.
- Replace domain-specific application logic.
- Force a single architecture style for all teams.

## Decisions

### Decision 1: Versioned blueprint packs
Blueprints are stored as versioned packs with metadata, templates, and post-generation checks.

### Decision 2: `sbk blueprint` command family
Add command surface:
- `sbk blueprint list`
- `sbk blueprint apply --name <blueprint> --target-repo-root <path>`
- `sbk blueprint verify --target-repo-root <path>`

### Decision 3: Baseline quality gates baked in
Each blueprint must include:
- CI entry workflow
- local verify command map
- operational runbook stub
- release readiness checklist

### Decision 4: Artifact-first architecture capture
Blueprint apply creates architecture docs and links them to OpenSpec change templates.

## Risks / Trade-offs

- [Risk] Blueprint sprawl can reduce consistency.
  - Mitigation: strict metadata schema and periodic blueprint certification.
- [Risk] Generated defaults may conflict with target organization conventions.
  - Mitigation: profile overlays and optional policy override files.

## Migration Plan

1. Define blueprint schema and loader.
2. Implement command surface and baseline pack templates.
3. Add blueprint verification flow.
4. Document blueprint lifecycle and governance.
