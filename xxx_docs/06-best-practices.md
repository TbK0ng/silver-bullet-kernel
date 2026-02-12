# Best Practices

## Architecture

- Keep artifacts as source of truth, not chat memory.
- Keep one owner per layer:
  - Trellis: execution policy
  - OpenSpec: change artifacts

## Coding

- Keep tasks small and verifiable.
- Prefer deterministic validation and explicit error handling.
- Add tests for both success and error paths.
- For symbol rename refactors, use semantic rename command (not text replace):
  - `npm run refactor:rename -- --file <path> --line <n> --column <n> --newName <name> --dryRun`

## Process

- Never skip proposal/design for non-trivial changes.
- Keep active change artifacts complete (proposal/design/tasks/spec delta) before verify.
- Keep active change `tasks.md` evidence strict:
  - `Task Evidence` heading is required
  - columns `Files`, `Action`, `Verify`, `Done` are required
  - rows must be non-empty and within configured granularity bounds
- Do not claim completion before verify passes.
- For repeated local failures, use bounded loop and capture diagnostics evidence:
  - `npm run verify:loop -- -Profile fast -MaxAttempts 2`
- Archive completed OpenSpec changes promptly.
- Treat `.trellis/spec/guides/constitution.md` as non-negotiable.
- Review weekly metrics and tune workflow by measured failure trends.
- Treat `workflow-policy.json` as reviewed policy-as-code, not local preference.
- Keep dispatcher orchestrator thin (no write-capable tools in dispatch frontmatter).
- Treat security gate failures as redaction incidents, not optional warnings.

## Collaboration

- Use worktree isolation for parallel work.
- Keep branch lifetime short.
- Capture session learnings with `/trellis:record-session`.
- Include `.trellis/workspace/` evidence updates for implementation branches.
- In owner session evidence, include `Memory Sources`, `Disclosure Level`, `Source IDs` markers.
- Use progressive disclosure memory retrieval before heavy context injection:
  - `npm run memory:context -- -Stage index`
  - `npm run memory:context -- -Stage detail -Ids <id-list>`

## Documentation

- Update `xxx_docs/` during implementation, not after.
- Include exact commands and file paths for reproducibility.
- Keep session and memory governance docs current with actual practice.
