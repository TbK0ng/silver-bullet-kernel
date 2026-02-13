## 1. Security Policy-As-Code

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `workflow-policy.json`, `scripts/workflow-policy-gate.ps1` | Add `securityGate` config and enforce denylisted sensitive path checks in governance gate. | `npm run workflow:policy` | Policy gate fails when implementation delta touches denylisted sensitive files. |
| 1.2 | [x] | `workflow-policy.json`, `scripts/workflow-policy-gate.ps1` | Add configurable secret-pattern scan for durable artifacts in current implementation scope. | `npm run workflow:policy` | Policy gate reports secret-like leakage and blocks verify. |

## 2. Task Evidence and Granularity Hardening

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 2.1 | [x] | `scripts/workflow-policy-gate.ps1` | Replace weak header-only check with strict canonical section parsing and non-empty row validation. | `npm run test:e2e` | Dummy header bypass no longer passes gate. |
| 2.2 | [x] | `workflow-policy.json`, `scripts/workflow-policy-gate.ps1` | Add row-level granularity constraints (`maxFilesPerTaskRow`, `maxActionLength`) and enforce them. | `npm run workflow:policy` | Oversized task rows fail with remediation. |

## 3. Memory Progressive Disclosure and Audit

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 3.1 | [x] | `scripts/memory-context.ps1`, `package.json` | Add staged memory retrieval script (`index/detail`) with auditable access logs. | `npm run memory:context -- -Stage index` | Script returns indexed sources and writes audit entries. |
| 3.2 | [x] | `workflow-policy.json`, `scripts/workflow-policy-gate.ps1` | Enforce owner-session evidence structure for memory disclosure metadata. | `npm run workflow:policy` | Missing disclosure metadata fails policy gate for implementation edits. |

## 4. Orchestrator and CI Determinism

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 4.1 | [x] | `workflow-policy.json`, `scripts/workflow-policy-gate.ps1` | Add orchestrator tool-boundary checks on dispatcher frontmatter. | `npm run workflow:policy` | Forbidden tool in dispatcher contract fails gate. |
| 4.2 | [x] | `scripts/common/verify-telemetry.ps1`, `scripts/collect-metrics.ps1`, `scripts/verify-ci.ps1` | Isolate CI telemetry path and consume deterministic metrics source in CI. | `npm run verify:ci` | CI indicator gate no longer depends on local telemetry history. |

## 5. Tests and Documentation

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 5.1 | [x] | `tests/e2e/workflow-policy-gate.e2e.test.ts`, `tests/e2e/memory-context.e2e.test.ts` | Add e2e coverage for strict task parsing, security scan, and memory context stages. | `npm run test:e2e` | New strict checks are regression-protected by tests. |
| 5.2 | [x] | `.trellis/spec/guides/*.md`, `docs/*.md`, `.codex/skills/memory-context/SKILL.md` | Update runbooks and Codex skill guides for security/memory/orchestrator strict rules. | `npm run verify:fast` | Docs and skill path are consistent with executable behavior. |
