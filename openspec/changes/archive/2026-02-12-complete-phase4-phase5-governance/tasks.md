## 1. Governance Policy Hardening

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `.trellis/spec/guides/constitution.md`, `.trellis/spec/guides/index.md` | Add constitutional project rules and register in guide index. | Manual file review. | Constitution exists and is discoverable from guide index. |
| 1.2 | [x] | `.trellis/spec/guides/memory-governance.md`, `AGENTS.md` | Define memory source, retention, injection, and redaction policy. | Manual file review. | Memory governance and redaction rules are codified. |
| 1.3 | [x] | `.trellis/workspace/sample-owner/index.md`, `.trellis/workspace/sample-owner/journal-1.md` | Add sample committed workspace journal for recovery proof. | Manual file review. | Sample journal format and recovery metadata are committed. |

## 2. Observability Tooling

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 2.1 | [x] | `scripts/common/verify-telemetry.ps1`, `scripts/verify-fast.ps1`, `scripts/verify.ps1`, `scripts/verify-ci.ps1` | Add verify-run telemetry for all verify entry points. | `npm run verify:fast`, `npm run verify:ci` | Verify scripts pass and append telemetry records. |
| 2.2 | [x] | `scripts/collect-metrics.ps1`, `package.json` | Implement weekly metrics aggregation command. | `npm run metrics:collect` | Metrics markdown and JSON summaries are generated. |
| 2.3 | [x] | `.gitignore` | Keep raw telemetry local to prevent noisy commits. | Manual file review. | `.metrics/` ignored from git. |

## 3. Documentation and Plan Completion

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 3.1 | [x] | `README.md`, `docs/05-quality-gates-and-ci.md`, `docs/06-best-practices.md`, `docs/09-plan-traceability.md` | Add governance and observability operation instructions. | Manual review and command checks. | Docs reflect current scripts, policy, and plan completion. |
| 3.2 | [x] | `docs/10-memory-governance-and-observability.md`, `docs/07-appdemo-validation-report.md`, `docs/00-index.md` | Add dedicated phase 4/5 runbook and update validation evidence. | `npm run demo:smoke`, `npm run verify:ci`, `npm run metrics:collect` | Runbook exists and validation evidence updated. |
