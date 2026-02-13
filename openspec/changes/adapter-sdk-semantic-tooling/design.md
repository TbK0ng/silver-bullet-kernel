## Context

Core adapter manifests are currently bundled in-repo and semantic tooling depth varies by language. This limits extensibility and creates uneven safety guarantees for refactors outside TypeScript.

## Goals / Non-Goals

**Goals**
- Externalize adapter extension through a stable SDK and validation pipeline.
- Add deterministic semantic tooling contract for Python/Go/Java/Rust.
- Keep adapter plugin behavior policy-gated and auditable.

**Non-Goals**
- Replace existing built-in adapters.
- Guarantee full IDE parity for all languages in first release.
- Auto-install external language servers.

## Decisions

### Decision 1: Adapter SDK manifest schema
Define plugin package contract with:
- metadata
- detect rules
- verify matrix
- policy scope declarations
- semantic tool capability map

### Decision 2: Adapter command family
Add:
- `sbk adapter list`
- `sbk adapter validate --path <adapter-pack>`
- `sbk adapter register --path <adapter-pack>`
- `sbk adapter doctor`

### Decision 3: Semantic tooling abstraction layer
Expose unified semantic operations:
- symbol rename
- reference map
- safe delete candidates
per language backend implementation.

### Decision 4: Fail-closed validation
Unvalidated adapter packs cannot be activated in strict profile.

## Risks / Trade-offs

- [Risk] Plugin ecosystem can fragment quality.
  - Mitigation: signed capability metadata + validation gate.
- [Risk] Cross-language semantic APIs have uneven maturity.
  - Mitigation: capability flags and deterministic fallback behavior.

## Migration Plan

1. Define adapter SDK schema and registry location.
2. Implement adapter command family and validator.
3. Add semantic abstraction and language backend hooks.
4. Add docs and compliance tests.
