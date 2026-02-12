## 1. Harden CI to Fail-Closed

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `scripts/workflow-policy-gate.ps1` | Remove CI fallback that weakens branch-delta checks and enforce fail-closed severity in CI. | `npm run verify:ci` | CI fails if base ref or required branch evidence is missing. |
| 1.2 | [x] | `.github/workflows/ci.yml` | Ensure checkout/base-ref wiring supports deterministic branch-delta checks. | CI dry run + `npm run verify:ci` | CI provides resolvable base ref and full history for gate logic. |

## 2. Enforce Owner and Worktree Rules

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 2.1 | [x] | `workflow-policy.json`, `scripts/workflow-policy-gate.ps1` | Add strict branch naming policy and owner/change extraction checks. | `npm run workflow:policy` | Branch name must match policy and change mapping requirements. |
| 2.2 | [x] | `scripts/workflow-policy-gate.ps1` | Enforce linked worktree requirement for local implementation edits. | `npm run workflow:policy` | Local implementation on main worktree fails policy gate. |
| 2.3 | [x] | `scripts/workflow-policy-gate.ps1` | Enforce owner-scoped session evidence paths. | `npm run workflow:policy` | Session evidence must align with extracted owner path. |

## 3. Docs and Spec Sync

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 3.1 | [x] | `.trellis/spec/guides/worktree-policy.md`, `.trellis/spec/guides/memory-governance.md`, `xxx_docs/04-two-person-collaboration.md`, `xxx_docs/05-quality-gates-and-ci.md`, `xxx_docs/08-troubleshooting.md` | Document strict branch/worktree requirements and remediation steps. | Manual review + gate output | Operators can resolve strict policy failures without ambiguity. |
| 3.2 | [x] | `openspec/changes/harden-fail-closed-owner-worktree-gates/specs/**` | Add spec deltas for fail-closed CI and owner/worktree enforcement. | `openspec validate --all --strict --no-interactive` | Spec deltas validate and mirror implementation behavior. |
