# Workflow Policy Gate

- generated_at_utc: 2026-02-12 10:37:57Z
- mode: ci
- outcome: PASS
- active_changes: none

## Checks

| Check | Severity | Status | Details | Remediation |
| --- | --- | --- | --- | --- |
| Implementation edits require active change or archive artifacts | fail | PASS | implementation_files=14; active_changes=0; has_archive_artifacts=True; files=.github/workflows/ci.yml, .trellis/spec/guides/memory-governance.md, .trellis/spec/guides/quality-gates.md, .trellis/spec/guides/worktree-policy.md, .trellis/workspace/index.md, AGENTS.md, CLAUDE.md, README.md (+6 more) | Create an OpenSpec change (openspec new change <name>) and complete artifacts before implementation, or archive completed change properly. |
| Canonical specs updated only via archive flow | fail | PASS | canonical_spec_files=3; has_archive_artifacts=True; files=openspec/specs/codex-workflow-kernel/spec.md, openspec/specs/memory-governance-policy/spec.md, openspec/specs/workflow-docs-system/spec.md | Avoid direct canonical spec edits during active implementation; use change deltas and openspec archive to merge. |
| Implementation branch matches owner/change pattern | fail | PASS | branch=sbk-codex-harden-fail-closed-owner-worktree-gates; valid=True; owner=codex; change=harden-fail-closed-owner-worktree-gates; reason= | Use branch format from workflow policy config (for example: sbk-codex-<change>). |
| Implementation scope maps to exactly one active change | fail | PASS | active_changes=0; has_archive_context=False | Keep one active OpenSpec change per implementation branch. |
| Branch change id matches active change | fail | PASS | branch_change=harden-fail-closed-owner-worktree-gates; active_change= | Rename branch or active change so branch <change> segment matches active OpenSpec change id. |
| Branch delta available for governance checks | fail | PASS | available=True; base_ref=main; merge_base=f5d5dd5664e22743e2e000cf4a6da20ce0beee8b; reason= | Set WORKFLOW_BASE_REF and ensure base branch history is fetched in CI. |
| Branch implementation delta includes OpenSpec change artifacts | fail | PASS | implementation_files=0; has_change_artifacts=False; files=none | Ensure branch includes openspec/changes/<name>/ artifacts for implementation changes. |
| Branch implementation delta includes session evidence | fail | PASS | implementation_files=0; expected_owner_prefix=.trellis/workspace/codex/; has_session_evidence=False | Record session evidence under owner workspace path before merge. |
