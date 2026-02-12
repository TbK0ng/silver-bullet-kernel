# Workflow Policy Gate

- generated_at_utc: 2026-02-12 10:05:23Z
- mode: local
- outcome: WARN
- active_changes: none

## Checks

| Check | Severity | Status | Details | Remediation |
| --- | --- | --- | --- | --- |
| Implementation edits require active change or archive artifacts | fail | PASS | implementation_files=21; active_changes=0; has_archive_artifacts=True; files=.trellis/spec/guides/memory-governance.md, .trellis/spec/guides/openspec-workflow.md, .trellis/spec/guides/quality-gates.md, .trellis/workspace/sample-owner/index.md, AGENTS.md, CLAUDE.md, README.md, openspec/specs/codex-workflow-kernel/spec.md (+13 more) | Create an OpenSpec change (openspec new change <name>) and complete artifacts before implementation, or archive completed change properly. |
| Canonical specs updated only via archive flow | fail | PASS | canonical_spec_files=5; has_archive_artifacts=True; files=openspec/specs/codex-workflow-kernel/spec.md, openspec/specs/memory-governance-policy/spec.md, openspec/specs/workflow-docs-system/spec.md, openspec/specs/workflow-doctor/spec.md, openspec/specs/workflow-observability/spec.md | Avoid direct canonical spec edits during active implementation; use change deltas and openspec archive to merge. |
| Branch delta available for governance checks | warn | FAIL | available=False; base_ref=; merge_base=; reason=No base ref available (set WORKFLOW_BASE_REF or fetch origin/main). | Fetch base branch and/or set WORKFLOW_BASE_REF to enable branch-delta governance checks. |
