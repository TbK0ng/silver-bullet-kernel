# OpenSpec Workflow (OPSX)

## Scope

This project uses OpenSpec OPSX as the source-of-truth workflow for change planning and traceability.

## Standard Loop

1. `opsx:new` create `openspec/changes/<change>/`
2. `opsx:ff` or `opsx:continue` create artifacts
3. `opsx:apply` implement tasks
4. `opsx:verify` validate implementation against artifacts
5. `opsx:archive` merge delta specs and archive completed change

## CLI Equivalent

When slash commands are unavailable:

- `openspec new change <name>`
- `openspec status --change <name>`
- `openspec instructions <artifact> --change <name>`
- `openspec validate --strict`
- `openspec archive <name> -y`

## Artifact Contract

Each active change must contain:

- `proposal.md`: why and scope
- `design.md`: decisions and trade-offs
- `tasks.md`: executable checklist with `Task Evidence` tables containing columns `Files`, `Action`, `Verify`, `Done`
- `specs/<capability>/spec.md`: requirement deltas

## Brownfield Rule

For existing repositories:

- Run onboarding once (`opsx:onboard`) or create equivalent baseline specs manually.
- Reference existing constraints and anti-patterns in proposal and design.
- Do not treat undocumented legacy behavior as free to break.

## Trellis Integration

- Use Trellis for context injection, worktree orchestration, and session recording.
- Use OpenSpec for planning artifacts and change lifecycle.
- Keep only one source of truth for each concern: Trellis for execution policy, OpenSpec for change artifacts.

## Enforced Gate Integration

- `npm run workflow:policy` must pass before and during implementation.
- `npm run verify:loop -- -Profile fast -MaxAttempts 2` is the preferred bounded verify/fix loop for repeated local failures.
- `npm run verify:ci` enforces policy + indicator gates for merge readiness.
- For implementation branches, include session evidence updates under `.trellis/workspace/`.
- Session evidence updates must include disclosure metadata markers:
  - `Memory Sources`, `Disclosure Level`, `Source IDs`
- CI telemetry is isolated to policy-configured path (`telemetry.ciVerifyRunsPath`) for deterministic indicator evaluation.
- CI push pipelines must pass event-correct base ref (`github.event.before`) to preserve branch-delta governance fidelity.
