# Workflow Policy Gate

- generated_at_utc: 2026-02-12 11:28:27Z
- mode: ci
- outcome: FAIL
- active_changes: none

## Checks

| Check | Severity | Status | Details | Remediation |
| --- | --- | --- | --- | --- |
| Implementation edits require active change or archive artifacts | fail | PASS | implementation_files=3; active_changes=0; has_archive_artifacts=True; files=openspec/specs/codex-workflow-kernel/spec.md, openspec/specs/workflow-docs-system/spec.md, openspec/specs/workflow-observability/spec.md | Create an OpenSpec change (openspec new change <name>) and complete artifacts before implementation, or archive completed change properly. |
| Canonical specs updated only via archive flow | fail | PASS | canonical_spec_files=3; has_archive_artifacts=True; files=openspec/specs/codex-workflow-kernel/spec.md, openspec/specs/workflow-docs-system/spec.md, openspec/specs/workflow-observability/spec.md | Avoid direct canonical spec edits during active implementation; use change deltas and openspec archive to merge. |
| Implementation branch matches owner/change pattern | fail | PASS | branch=sbk-codex-close-gap-13-thought-enforcement; valid=True; owner=codex; change=close-gap-13-thought-enforcement; reason= | Use branch format from workflow policy config (for example: sbk-codex-<change>). |
| Implementation scope maps to exactly one active change | fail | FAIL | active_changes=0; has_archive_context=False | Keep one active OpenSpec change per implementation branch. |
| Branch change id matches active change | fail | PASS | branch_change=close-gap-13-thought-enforcement; active_change= | Rename branch or active change so branch <change> segment matches active OpenSpec change id. |
| Branch delta available for governance checks | fail | PASS | available=True; base_ref=main; base_sha=2838935d9425d9e94bf9640a3b2179a0d7c15c98; head_sha=f1be91cf8ff7a94829bfb55ffb92bcc23b0e0670; merge_base=2838935d9425d9e94bf9640a3b2179a0d7c15c98; reason= | Set WORKFLOW_BASE_REF and ensure base branch history is fetched in CI. |
| Branch implementation delta includes OpenSpec change artifacts | fail | PASS | implementation_files=21; has_change_artifacts=True; files=.claude/agents/plan.md, .claude/commands/trellis/parallel.md, .codex/skills/semantic-rename/SKILL.md, .github/workflows/ci.yml, .trellis/spec/guides/openspec-workflow.md, .trellis/spec/guides/quality-gates.md, .trellis/spec/guides/worktree-policy.md, .trellis/workspace/codex/index.md (+13 more) | Ensure branch includes openspec/changes/<name>/ artifacts for implementation changes. |
| Branch implementation delta includes session evidence | fail | PASS | implementation_files=21; expected_owner_prefix=.trellis/workspace/codex/; has_session_evidence=True | Record session evidence under owner workspace path before merge. |
