## 1. CI Fail-Closed Delta Integrity

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `.github/workflows/ci.yml` | Use push-event base commit for `WORKFLOW_BASE_REF` instead of `origin/main` to preserve branch delta signal on `push main`. | CI workflow lint + `npm run verify:ci` | CI policy gate evaluates non-empty change range for push events and remains fail-closed when base cannot be resolved. |
| 1.2 | [x] | `scripts/workflow-policy-gate.ps1` | Fail when resolved CI base ref equals current `HEAD` and include remediation details. | `npm run verify:ci` | Misconfigured CI base ref no longer passes with empty delta context. |

## 2. Artifact-First Evidence Hardening

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 2.1 | [x] | `scripts/workflow-policy-gate.ps1` | Enforce active-change `tasks.md` schema header requiring `Files/Action/Verify/Done` columns. | `npm run workflow:policy` | Active change with malformed task evidence table fails policy gate. |
| 2.2 | [x] | `workflow-policy.json` | Add configurable required task evidence columns for policy-as-code control. | `npm run workflow:policy` | Required columns are sourced from policy config and reflected in reports. |

## 3. Deterministic Execution Enhancements

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 3.1 | [x] | `scripts/verify-loop.ps1`, `package.json` | Add bounded verify/fix loop command with diagnostics and loop evidence artifacts. | `npm run verify:loop -- -MaxAttempts 2` | Loop persists attempt history and exits deterministically on pass/fail. |
| 3.2 | [x] | `scripts/semantic-rename.ts`, `package.json` | Add TypeScript semantic rename command for AST-level deterministic refactor operations. | `npm run refactor:rename -- --file src/app.ts --line 4 --column 7 --newName createTaskPayload --dryRun` | Symbol rename flow is executable and validates cursor target. |
| 3.3 | [x] | `.codex/skills/semantic-rename/SKILL.md` | Add Codex skill instructions to invoke semantic rename safely in workflow. | Manual runbook review + command dry-run | Codex path includes concrete LSP/AST-like refactor SOP. |

## 4. Docs and Spec Sync

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 4.1 | [x] | `.trellis/spec/guides/quality-gates.md`, `.trellis/spec/guides/openspec-workflow.md`, `docs/05-quality-gates-and-ci.md`, `docs/06-best-practices.md`, `docs/08-troubleshooting.md` | Document strict task schema, verify loop usage, and semantic rename workflow. | Manual review + `npm run verify:fast` | Operators can execute and remediate new hard checks without ambiguity. |
| 4.2 | [x] | `openspec/changes/close-gap-13-thought-enforcement/specs/**` | Add deltas for CI delta integrity, task evidence schema enforcement, verify loop, and semantic refactor capability. | `openspec validate --all --strict --no-interactive` | Spec deltas validate and align with implementation behavior. |
