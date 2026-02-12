# Brownfield Onboarding

## Objective

Before changing code in an existing repository, establish factual baseline and risk boundaries.

## Checklist

- Run `npm run map:codebase` to snapshot current structure.
- Identify invariants:
  - APIs that must remain backward compatible
  - Existing data contracts
  - CI-required checks
- Identify high-risk areas:
  - shared utilities
  - cross-layer boundary code
  - public interfaces
- Capture change scope in OpenSpec:
  - `openspec new change <name>`
  - `openspec status --change <name>`
  - create proposal/design/specs/tasks artifacts before coding

## Baseline Verify

Run and record outputs before coding:

- `npm run verify:fast`
- `npm run verify`

If baseline is already failing, fix baseline first or explicitly isolate pre-existing failures in the change proposal.
