# Worktree Policy

## Goal

Use isolated worktrees to increase parallel throughput while reducing merge conflicts.

## Naming Convention

Use this format:

- `sbk-<owner>-<change>`

Examples:

- `sbk-alice-bootstrap-codex-workflow-kernel`
- `sbk-bob-appdemo-crud-hardening`

## Ownership Rule

- One OpenSpec change has one owner at a time.
- Reviewer must be the non-owner collaborator.
- Do not co-edit the same active change in two worktrees.

## Branching and Merge

- One branch per OpenSpec change.
- Rebase on latest `main` before opening PR.
- Squash merge for small scoped changes.
- Keep atomic commits when the change is large and likely to need bisect.

## Spec Conflict Control

- Do not edit `openspec/specs/**` directly during parallel implementation.
- Edit only `openspec/changes/<change>/specs/**`.
- Merge to `openspec/specs/**` only through `openspec archive`.

## Cleanup Rule

After merge and archive:

- Delete worktree branch if no longer needed.
- Remove stale worktrees under `trellis-worktrees/`.
