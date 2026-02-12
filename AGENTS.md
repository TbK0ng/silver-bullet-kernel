<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

Use the `/trellis:start` command when starting a new session to:
- Initialize your developer identity
- Understand current project context
- Read relevant guidelines

Use `@/.trellis/` to learn:
- Development workflow (`workflow.md`)
- Project structure guidelines (`spec/`)
- Developer workspace (`workspace/`)

Keep this managed block so 'trellis update' can refresh the instructions.

<!-- TRELLIS:END -->

# Project Runtime Policy

## Runtime Target

- Primary: Codex
- Secondary: Claude Code

## Change Control

- Every non-trivial change MUST map to one OpenSpec change directory under `openspec/changes/<name>/`.
- Do not start implementation before proposal and design exist.
- Verification fails when implementation edits are not traceable to OpenSpec artifacts.

## Verification

- Fast local gate: `npm run verify:fast`
- Full local gate: `npm run verify`
- CI gate: `npm run verify:ci`
- Policy gate: `npm run workflow:policy`
- Indicator gate: `npm run workflow:gate`

## Artifact and Memory Discipline

- Source of truth for change intent: OpenSpec artifacts.
- Source of truth for execution policy: Trellis specs and guides.
- Session memory must be recorded with `/trellis:record-session` at end of work sessions.
- Implementation changes in CI must include session evidence updates under `.trellis/workspace/`.
- Never store secrets in memory artifacts; redact before recording.
- Generate weekly observability report with `npm run metrics:collect`.
