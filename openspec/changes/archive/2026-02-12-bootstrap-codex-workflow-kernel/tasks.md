## 1. Bootstrap Codex-First Workflow Kernel

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `.trellis/**`, `.claude/**`, `.codex/**`, `AGENTS.md` | Initialize Trellis + OpenSpec and ensure Codex skills are available. | Presence of generated runtime folders and skills. | Trellis and OpenSpec initialized; `.codex/skills` contains both Trellis and OpenSpec skill sets. |
| 1.2 | [x] | `.trellis/spec/guides/quality-gates.md`, `.trellis/spec/guides/worktree-policy.md`, `.trellis/spec/guides/openspec-workflow.md`, `.trellis/spec/guides/index.md`, `.trellis/worktree.yaml` | Add enforceable quality gates, worktree policy, and OpenSpec lifecycle guide. | Manual review of policy files and worktree verify command. | Quality policy and parallel policy are codified and index-linked. |
| 1.3 | [x] | `scripts/verify-fast.ps1`, `scripts/verify.ps1`, `scripts/verify-ci.ps1`, `.github/workflows/ci.yml` | Implement deterministic verification entry points and CI gate. | `npm run verify:fast`, `npm run verify`, `npm run verify:ci` (local), and CI workflow syntax check. | Verify scripts and CI gate committed; CI invokes single source verify script. |

## 2. Build Usability Proof App (`appdemo`)

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 2.1 | [x] | `src/app.ts`, `src/server.ts` | Build a task API with validation and update flow. | `npm run build`, API route smoke checks. | Health, list, create, update endpoints implemented with validation and error handling. |
| 2.2 | [x] | `tests/e2e/app.e2e.test.ts`, `vitest.config.ts` | Add e2e tests for behavior and regression safety. | `npm run test`, `npm run test:e2e`. | Endpoint behavior covered for success + error paths. |

## 3. Deliver Project-Owned Operational Docs

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 3.1 | [x] | `docs/*.md` | Write setup, SOP, brownfield onboarding, troubleshooting, and best-practice docs. | Manual doc review against implementation files. | `docs` includes complete runbook and collaboration best practices. |
| 3.2 | [x] | `README.md` | Document runnable developer entry points and demo commands. | Follow README steps in clean shell. | README commands map to actual scripts and current project layout. |
