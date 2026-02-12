# Quality Gates

## Why

This repository treats completion claims as invalid until objective verification passes.

## Required Verify Entry Points

- Local fast gate: `npm run verify:fast`
- Local full gate: `npm run verify`
- CI gate: `npm run verify:ci`
- Policy gate: `npm run workflow:policy`
- Indicator gate: `npm run workflow:gate`

## Completion Criteria

Any code task is complete only when all criteria pass:

- Workflow policy gate passes.
- Lint passes with zero warnings configured by policy.
- Type checking passes.
- Tests pass, including e2e tests for user-facing behavior.
- Build succeeds.
- OpenSpec strict validation passes for current artifacts.
- Indicator gate thresholds do not fail.

## Evidence Rule

Every OpenSpec task must include:

- `files`: exact files changed
- `action`: what changed and why
- `verify`: command(s) run
- `done`: observable outcome

## Failure Handling

When verify fails, record:

- Symptom
- Root-cause hypothesis
- Fix applied
- Re-run result

Do not archive a change with unresolved verify failures.

## Hard Governance Rules

- Implementation edits must be traceable to `openspec/changes/<name>/` artifacts.
- Active change artifacts must include proposal/design/tasks/spec delta before verify succeeds.
- CI branch delta must include:
  - OpenSpec change artifacts for implementation edits.
  - Session evidence updates under `.trellis/workspace/`.
