# Codex Daily SOP

## Start of Day

1. `git pull --rebase`
2. Read `AGENTS.md`
3. Review active change:
   - `openspec list`
   - `openspec status --change <name>`
4. Run `npm run verify:fast`
5. Run `npm run workflow:policy`

## During Implementation

1. Work only inside one active OpenSpec change scope.
2. Keep tasks and specs synchronized with real code progress.
3. Run `npm run verify:fast` after each meaningful code batch.
4. Keep active change artifacts complete before moving to implementation-heavy edits.

## Before PR

1. `npm run verify`
2. `npm run demo:smoke` for app-level sanity
3. `openspec validate --all --strict --no-interactive`
4. `npm run workflow:gate`
5. Update change tasks with verify evidence and outcomes.

## End of Session

1. Run `/trellis:record-session`
2. Update runbook docs in `xxx_docs/` if new lessons were learned.
