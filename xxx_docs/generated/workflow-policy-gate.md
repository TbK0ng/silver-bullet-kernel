# Workflow Policy Gate

- generated_at_utc: 2026-02-12 11:21:39Z
- mode: local
- outcome: WARN
- active_changes: close-gap-13-thought-enforcement

## Checks

| Check | Severity | Status | Details | Remediation |
| --- | --- | --- | --- | --- |
| Implementation edits require active change or archive artifacts | fail | PASS | implementation_files=21; active_changes=1; has_archive_artifacts=False; files=.claude/agents/plan.md, .claude/commands/trellis/parallel.md, .github/workflows/ci.yml, .trellis/spec/guides/openspec-workflow.md, .trellis/spec/guides/quality-gates.md, .trellis/spec/guides/worktree-policy.md, .trellis/workspace/codex/index.md, .trellis/workspace/index.md (+13 more) | Create an OpenSpec change (openspec new change <name>) and complete artifacts before implementation, or archive completed change properly. |
| Active change 'close-gap-13-thought-enforcement' has complete artifacts | fail | PASS | proposal=True; design=True; tasks=True; delta_specs=3 | Ensure proposal.md, design.md, tasks.md, and at least one spec delta file exist under the active change. |
| Active change 'close-gap-13-thought-enforcement' tasks evidence schema is complete | fail | PASS | required=Files, Action, Verify, Done; matched_header=ID, Status, Files, Action, Verify, Done; reason= | Use a tasks table header that includes: Files, Action, Verify, Done. |
| Canonical specs updated only via archive flow | fail | PASS | canonical_spec_files=0; has_archive_artifacts=False; files=none | Avoid direct canonical spec edits during active implementation; use change deltas and openspec archive to merge. |
| Implementation branch matches owner/change pattern | fail | PASS | branch=sbk-codex-close-gap-13-thought-enforcement; valid=True; owner=codex; change=close-gap-13-thought-enforcement; reason= | Use branch format from workflow policy config (for example: sbk-codex-<change>). |
| Implementation scope maps to exactly one active change | fail | PASS | active_changes=1; has_archive_context=False | Keep one active OpenSpec change per implementation branch. |
| Branch change id matches active change | fail | PASS | branch_change=close-gap-13-thought-enforcement; active_change=close-gap-13-thought-enforcement | Rename branch or active change so branch <change> segment matches active OpenSpec change id. |
| Local implementation runs from linked worktree | fail | PASS | git_dir_raw=E:/docc/silver-bullet-kernel/.git/worktrees/sbk-codex-close-gap-13-thought-enforcement; git_dir_full=E:/docc/silver-bullet-kernel/.git/worktrees/sbk-codex-close-gap-13-thought-enforcement; is_linked=True | Run implementation in linked worktree (git worktree add) using one branch per change. |
| Local implementation includes owner-scoped session evidence | fail | PASS | owner_prefix=.trellis/workspace/codex/; has_owner_session_evidence=True | Update session evidence under .trellis/workspace/codex/ before verify. |
| Branch delta available for governance checks | warn | FAIL | available=False; base_ref=; base_sha=; head_sha=2838935d9425d9e94bf9640a3b2179a0d7c15c98; merge_base=; reason=No base ref available (set WORKFLOW_BASE_REF or ensure origin base branch is fetched). | Set WORKFLOW_BASE_REF and ensure base branch history is fetched in CI. |
