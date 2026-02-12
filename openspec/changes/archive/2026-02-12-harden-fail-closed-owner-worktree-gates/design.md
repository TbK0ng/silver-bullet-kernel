## Context

The workflow now has policy and indicator gates, but strictness is diluted by operational fallback:

- CI can pass without trustworthy branch delta.
- Owner/worktree discipline remains a convention.

Strict governance requires deterministic fail behavior and explicit owner/worktree validation.

## Goals / Non-Goals

**Goals**

- CI policy checks fail when base branch is unavailable.
- Owner and change naming constraints are enforced via branch pattern.
- Implementation work in local mode requires linked worktree.
- Session evidence must align with extracted owner identity.

**Non-Goals**

- Building a full identity management system.
- Enforcing GitHub-specific metadata outside generic git refs.

## Decisions

### Decision 1: Fail-closed CI branch delta

In `Mode=ci`, branch-delta availability and branch evidence checks are `fail`, not `warn`.  
No `HEAD^` fallback is allowed in CI.

### Decision 2: Policy-as-code owner extraction

Add configurable `branchPattern` with named groups `owner` and `change`.
All owner-linked checks derive from this extraction.

### Decision 3: Linked worktree requirement for local implementation

When implementation edits are detected in local mode, repository must be a linked worktree (`.git/worktrees/...` git-dir semantics), not main worktree.

### Decision 4: Owner-scoped session evidence

Session evidence path must include the extracted owner path under `.trellis/workspace/<owner>/`.

## Risks / Trade-offs

- Strict branch pattern may require one-time team branch-renaming cleanup.
- Linked worktree requirement raises local setup cost but enforces clean parallel isolation.
- CI base ref handling depends on checkout history depth; workflow updated to fetch full history.
