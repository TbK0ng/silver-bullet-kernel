# Workflow Policy Gate

- generated_at_utc: 2026-02-13 15:41:26Z
- mode: local
- outcome: FAIL
- active_changes: fix-usability-closure

## Checks

| Check | Severity | Status | Details | Remediation |
| --- | --- | --- | --- | --- |
| Implementation edits require active change or archive artifacts | fail | PASS | implementation_files=7; active_changes=1; has_archive_artifacts=False; files=.github/workflows/ci.yml, .trellis/workspace/codex/journal-2.md, eslint.config.js, package.json, scripts/memory-context.ps1, scripts/workflow-doctor.ps1, tests/e2e/memory-context.e2e.test.ts | Create an OpenSpec change (openspec new change <name>) and complete artifacts before implementation, or archive completed change properly. |
| Active change 'fix-usability-closure' has complete artifacts | fail | PASS | proposal=True; design=True; tasks=True; delta_specs=2 | Ensure proposal.md, design.md, tasks.md, and at least one spec delta file exist under the active change. |
| Active change 'fix-usability-closure' tasks evidence schema is complete | fail | PASS | required_heading=Task Evidence; required_columns=Files, Action, Verify, Done; matched_header=ID, Status, Files, Action, Verify, Done; row_count=6; reason=; violations=none | Use heading 'Task Evidence' with non-empty task evidence rows and bounded granularity. |
| Canonical specs updated only via archive flow | fail | PASS | canonical_spec_files=0; has_archive_artifacts=False; files=none | Avoid direct canonical spec edits during active implementation; use change deltas and openspec archive to merge. |
| Implementation delta excludes denylisted sensitive paths | fail | PASS | implementation_files=7; sensitive_hits=none | Remove edits to denylisted sensitive files or update policy with explicit reviewed exception. |
| Durable artifact secret-pattern scan passes | fail | PASS | scan_targets=9; secret_hits=none | Redact credential-like material from durable artifacts and rerun verify. |
| Dispatcher '.claude/agents/dispatch.md' keeps thin orchestrator tool boundary | fail | PASS | available=True; tools=Read, Bash, mcp__exa__web_search_exa, mcp__exa__get_code_context_exa; forbidden_found=none; reason= | Keep dispatch agent read/route-only; remove forbidden write-capable tools from frontmatter. |
| Implementation branch matches owner/change pattern | fail | PASS | branch=sbk-codex-fix-usability-closure; valid=True; owner=codex; change=fix-usability-closure; reason= | Use branch format from workflow policy config (for example: sbk-codex-<change>). |
| Implementation scope maps to exactly one active change | fail | PASS | active_changes=1; has_archive_context=False | Keep one active OpenSpec change per implementation branch. |
| Branch change id matches active change | fail | PASS | branch_change=fix-usability-closure; active_change=fix-usability-closure | Rename branch or active change so branch <change> segment matches active OpenSpec change id. |
| Local implementation runs from linked worktree | fail | FAIL | git_dir_raw=.git; git_dir_full=E:\docc\silver-bullet-kernel\.git; is_linked=False | Run implementation in linked worktree (git worktree add) using one branch per change. |
| Local implementation includes owner-scoped session evidence | fail | PASS | owner_prefix=.trellis/workspace/codex/; has_owner_session_evidence=True | Update session evidence under .trellis/workspace/codex/ before verify. |
| Owner session evidence includes disclosure metadata | fail | PASS | required_markers=Memory Sources, Disclosure Level, Source IDs; files_checked=1; violations=none | Add disclosure metadata markers to owner session evidence: Memory Sources, Disclosure Level, Source IDs. |
| Branch delta available for governance checks | warn | FAIL | available=False; base_ref=; base_sha=; head_sha=0a235ac7584ba6ae00b8115f802421f5a5557303; merge_base=; reason=No base ref available (set WORKFLOW_BASE_REF or ensure origin base branch is fetched). | Set WORKFLOW_BASE_REF and ensure base branch history is fetched in CI. |
