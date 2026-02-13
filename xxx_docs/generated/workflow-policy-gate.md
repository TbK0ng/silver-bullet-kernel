# Workflow Policy Gate

- generated_at_utc: 2026-02-13 15:52:29Z
- mode: ci
- outcome: PASS
- active_changes: fix-usability-closure

## Checks

| Check | Severity | Status | Details | Remediation |
| --- | --- | --- | --- | --- |
| Implementation edits require active change or archive artifacts | fail | PASS | implementation_files=2; active_changes=1; has_archive_artifacts=False; files=scripts/workflow-policy-gate.ps1, tests/e2e/workflow-policy-gate.e2e.test.ts | Create an OpenSpec change (openspec new change <name>) and complete artifacts before implementation, or archive completed change properly. |
| Active change 'fix-usability-closure' has complete artifacts | fail | PASS | proposal=True; design=True; tasks=True; delta_specs=2 | Ensure proposal.md, design.md, tasks.md, and at least one spec delta file exist under the active change. |
| Active change 'fix-usability-closure' tasks evidence schema is complete | fail | PASS | required_heading=Task Evidence; required_columns=Files, Action, Verify, Done; matched_header=ID, Status, Files, Action, Verify, Done; row_count=6; reason=; violations=none | Use heading 'Task Evidence' with non-empty task evidence rows and bounded granularity. |
| Canonical specs updated only via archive flow | fail | PASS | canonical_spec_files=0; has_archive_artifacts=False; files=none | Avoid direct canonical spec edits during active implementation; use change deltas and openspec archive to merge. |
| Implementation delta excludes denylisted sensitive paths | fail | PASS | implementation_files=7; sensitive_hits=none | Remove edits to denylisted sensitive files or update policy with explicit reviewed exception. |
| Durable artifact secret-pattern scan passes | fail | PASS | scan_targets=14; secret_hits=none | Redact credential-like material from durable artifacts and rerun verify. |
| Dispatcher '.claude/agents/dispatch.md' keeps thin orchestrator tool boundary | fail | PASS | available=True; tools=Read, Bash, mcp__exa__web_search_exa, mcp__exa__get_code_context_exa; forbidden_found=none; reason= | Keep dispatch agent read/route-only; remove forbidden write-capable tools from frontmatter. |
| Implementation branch matches owner/change pattern | fail | PASS | branch=sbk-codex-fix-usability-closure; valid=True; owner=codex; change=fix-usability-closure; reason= | Use branch format from workflow policy config (for example: sbk-codex-<change>). |
| Implementation scope maps to exactly one active change | fail | PASS | active_changes=1; has_archive_context=False | Keep one active OpenSpec change per implementation branch. |
| Branch change id matches active change | fail | PASS | branch_change=fix-usability-closure; active_change=fix-usability-closure | Rename branch or active change so branch <change> segment matches active OpenSpec change id. |
| Owner session evidence includes disclosure metadata | fail | PASS | required_markers=Memory Sources, Disclosure Level, Source IDs; files_checked=1; violations=none | Add disclosure metadata markers to owner session evidence: Memory Sources, Disclosure Level, Source IDs. |
| Branch delta available for governance checks | fail | PASS | available=True; base_ref=HEAD~1; base_sha=0a235ac7584ba6ae00b8115f802421f5a5557303; head_sha=827868027c8df0aaf02c1a77f6d9cfc8fcec9a08; merge_base=0a235ac7584ba6ae00b8115f802421f5a5557303; reason= | Set WORKFLOW_BASE_REF and ensure base branch history is fetched in CI. |
| Branch implementation delta includes OpenSpec change artifacts | fail | PASS | implementation_files=7; has_change_artifacts=True; files=.github/workflows/ci.yml, .trellis/workspace/codex/journal-2.md, eslint.config.js, package.json, scripts/memory-context.ps1, scripts/workflow-doctor.ps1, tests/e2e/memory-context.e2e.test.ts | Ensure branch includes openspec/changes/<name>/ artifacts for implementation changes. |
| Branch implementation delta includes session evidence | fail | PASS | implementation_files=7; expected_owner_prefix=.trellis/workspace/codex/; has_session_evidence=True | Record session evidence under owner workspace path before merge. |
