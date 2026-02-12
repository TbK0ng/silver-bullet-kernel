# Quality Gates

## Why

This repository treats completion claims as invalid until objective verification passes.

## Required Verify Entry Points

- Local fast gate: `npm run verify:fast`
- Local full gate: `npm run verify`
- Local bounded fix loop: `npm run verify:loop -- -Profile fast -MaxAttempts 2`
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

- `Files`: exact files changed
- `Action`: what changed and why
- `Verify`: command(s) run
- `Done`: observable outcome

`tasks.md` evidence is enforced by policy gate:

- required heading: `Task Evidence`
- required columns: `Files`, `Action`, `Verify`, `Done`
- at least one non-empty data row
- bounded granularity per row (`maxFilesPerTaskRow`, `maxActionLength` from `workflow-policy.json`)

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
- Active change `tasks.md` must include evidence columns: `Files`, `Action`, `Verify`, `Done`.
- Branch must match `sbk-<owner>-<change>` and `<change>` must map to active change.
- Local implementation must run in linked worktree (`.git/worktrees/...`).
- CI branch delta base ref must not resolve to current `HEAD`.
- CI branch delta must include:
  - OpenSpec change artifacts for implementation edits.
  - Session evidence updates under owner path `.trellis/workspace/<owner>/`.
- Session evidence files must include disclosure metadata markers:
  - `Memory Sources`, `Disclosure Level`, `Source IDs`.
- Security policy is fail-closed:
  - implementation deltas cannot touch denylisted sensitive paths.
  - durable artifacts are scanned for secret-like patterns.
- Dispatcher orchestrator must remain thin:
  - forbidden write-capable tools in `.claude/agents/dispatch.md` fail policy gate.
