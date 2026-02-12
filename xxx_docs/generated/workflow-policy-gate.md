# Workflow Policy Gate

- generated_at_utc: 2026-02-12 12:27:22Z
- mode: ci
- outcome: PASS
- active_changes: none

## Checks

| Check | Severity | Status | Details | Remediation |
| --- | --- | --- | --- | --- |
| Implementation edits require active change or archive artifacts | fail | PASS | implementation_files=0; active_changes=0; has_archive_artifacts=False; files=none | Create an OpenSpec change (openspec new change <name>) and complete artifacts before implementation, or archive completed change properly. |
| Canonical specs updated only via archive flow | fail | PASS | canonical_spec_files=0; has_archive_artifacts=False; files=none | Avoid direct canonical spec edits during active implementation; use change deltas and openspec archive to merge. |
| Implementation delta excludes denylisted sensitive paths | fail | PASS | implementation_files=26; sensitive_hits=none | Remove edits to denylisted sensitive files or update policy with explicit reviewed exception. |
| Durable artifact secret-pattern scan passes | fail | PASS | scan_targets=24; secret_hits=none | Redact credential-like material from durable artifacts and rerun verify. |
| Dispatcher '.claude/agents/dispatch.md' keeps thin orchestrator tool boundary | fail | PASS | available=True; tools=Read, Bash, mcp__exa__web_search_exa, mcp__exa__get_code_context_exa; forbidden_found=none; reason= | Keep dispatch agent read/route-only; remove forbidden write-capable tools from frontmatter. |
| Implementation branch matches owner/change pattern | fail | PASS | branch=sbk-codex-strict-plan13-philosophy; valid=True; owner=codex; change=strict-plan13-philosophy; reason= | Use branch format from workflow policy config (for example: sbk-codex-<change>). |
| Implementation scope maps to exactly one active change | fail | PASS | active_changes=0; has_archive_context=True | Keep one active OpenSpec change per implementation branch. |
| Branch change id matches active change | fail | PASS | branch_change=strict-plan13-philosophy; active_change= | Rename branch or active change so branch <change> segment matches active OpenSpec change id. |
| Owner session evidence includes disclosure metadata | fail | PASS | required_markers=Memory Sources, Disclosure Level, Source IDs; files_checked=1; violations=none | Add disclosure metadata markers to owner session evidence: Memory Sources, Disclosure Level, Source IDs. |
| Branch delta available for governance checks | fail | PASS | available=True; base_ref=main; base_sha=97d71a1ccab4f8ffa340c3cde631af1b4b6722b7; head_sha=a2b5726e22e4907848cc3d05ad78d2aeef709cb6; merge_base=97d71a1ccab4f8ffa340c3cde631af1b4b6722b7; reason= | Set WORKFLOW_BASE_REF and ensure base branch history is fetched in CI. |
| Branch implementation delta includes OpenSpec change artifacts | fail | PASS | implementation_files=26; has_change_artifacts=True; files=.claude/skills/memory-context/SKILL.md, .codex/skills/memory-context/SKILL.md, .trellis/spec/guides/memory-governance.md, .trellis/spec/guides/openspec-workflow.md, .trellis/spec/guides/quality-gates.md, .trellis/workspace/codex/index.md, .trellis/workspace/codex/journal-2.md, .trellis/workspace/index.md (+18 more) | Ensure branch includes openspec/changes/<name>/ artifacts for implementation changes. |
| Branch implementation delta includes session evidence | fail | PASS | implementation_files=26; expected_owner_prefix=.trellis/workspace/codex/; has_session_evidence=True | Record session evidence under owner workspace path before merge. |
