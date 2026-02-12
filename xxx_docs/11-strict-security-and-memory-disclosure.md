# Strict Security and Memory Disclosure

## Goal

Make security and memory governance fail-closed, not convention-only.

## Security Policy-as-Code

Policy source: `workflow-policy.json` (`securityGate` section)

Enforced by `npm run workflow:policy`:

1. Denylisted sensitive path edits in implementation deltas.
2. Secret-pattern scan for durable artifacts:
   - `.trellis/workspace/`
   - `openspec/`
   - `xxx_docs/`

If a credential-like match is detected, policy gate fails with file-level detail.

## Progressive Disclosure Memory Contract

Use staged memory retrieval:

1. Index stage:
   - `npm run memory:context -- -Stage index`
2. Detail stage by selected IDs:
   - `npm run memory:context -- -Stage detail -Ids S001,S003`

Audit artifact:

- `.metrics/memory-context-audit.jsonl`

## Owner Session Evidence Markers

When updating owner session evidence (`.trellis/workspace/<owner>/`), include:

- `Memory Sources`
- `Disclosure Level`
- `Source IDs`

Missing markers are blocked by policy gate.

## Thin Orchestrator Rule

Dispatcher contract is enforced by policy gate (`orchestratorGate`):

- target: `.claude/agents/dispatch.md`
- forbidden tools: `Write`, `Edit`, `MultiEdit`

This keeps orchestrator routing-only and pushes implementation to executors.

## CI Determinism Note

`verify:ci` isolates telemetry input path via policy config (`telemetry.ciVerifyRunsPath`), so indicator checks are reproducible and not polluted by local workstation history.
