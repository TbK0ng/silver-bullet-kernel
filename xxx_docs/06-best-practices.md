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

## Process

- Never skip proposal/design for non-trivial changes.
- Do not claim completion before verify passes.
- Archive completed OpenSpec changes promptly.

## Collaboration

- Use worktree isolation for parallel work.
- Keep branch lifetime short.
- Capture session learnings with `/trellis:record-session`.

## Documentation

- Update `xxx_docs/` during implementation, not after.
- Include exact commands and file paths for reproducibility.
