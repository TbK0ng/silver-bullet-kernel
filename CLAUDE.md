# Claude Runtime Notes

This repository follows the same policy as `AGENTS.md`.

## Required Workflow

1. Start with Trellis context (`/trellis:start`).
2. Create or select an OpenSpec change (`/opsx:new` or existing).
3. Build and validate with project verify scripts.
4. Record session with `/trellis:record-session`.
5. Use branch `sbk-<owner>-<change>` and linked worktree for implementation.

## Required Gates

- `npm run verify:fast`
- `npm run verify`
- `npm run verify:loop -- -Profile fast -MaxAttempts 2`
- `npm run verify:ci`
- `npm run workflow:policy`
- `npm run workflow:gate`
- `npm run memory:context -- -Stage index`

## Source of Truth

- Execution and quality policy: `.trellis/spec/guides/`
- Change artifacts and requirements: `openspec/`
- Owner session evidence must include disclosure markers:
  - `Memory Sources`
  - `Disclosure Level`
  - `Source IDs`
