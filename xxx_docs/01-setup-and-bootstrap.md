# Setup and Bootstrap

## Environment

- OS: Windows (PowerShell-first scripts)
- Node: `>=20.19.0`
- npm: `>=10`
- OpenSpec CLI: global install required for strict validation

## Bootstrap Steps

1. Install dependencies:
   - `npm install`
2. Verify local baseline:
   - `npm run verify:fast`
3. Generate codebase map:
   - `npm run map:codebase`
4. Run full local verification:
   - `npm run verify`

## Runtime Initialization (Already Wired)

- Trellis assets: `.trellis/`, `.claude/`, `.agents/`
- Codex skills: `.codex/skills/` (Trellis + OpenSpec)
- OpenSpec root: `openspec/`

## Required Files to Check Before Starting Work

- `AGENTS.md`
- `.trellis/spec/guides/quality-gates.md`
- `.trellis/spec/guides/worktree-policy.md`
- `.trellis/spec/guides/openspec-workflow.md`
