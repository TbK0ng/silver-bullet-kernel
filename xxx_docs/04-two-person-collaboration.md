# Two-Person Collaboration SOP

## Roles Per Change

- One owner per OpenSpec change
- One reviewer (the other collaborator)

Swap roles by change, not within same change.

## Parallel Strategy

- One change = one branch = one worktree owner
- No dual ownership in a single active change
- Rebase frequently on `main`

## Merge Discipline

- Small changes: squash merge
- Larger changes: preserve atomic commits
- Never merge failing verify gates
- Never merge branch deltas missing session evidence updates under `.trellis/workspace/`

## Conflict Avoidance

- Do not edit `openspec/specs/**` directly in active parallel work
- Use `openspec/changes/<name>/specs/**` and merge through `openspec archive`
- Coordinate shared module touches in proposal and tasks before coding
