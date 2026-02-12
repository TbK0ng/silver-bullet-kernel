# Workflow Doctor Report

- generated_at_utc: 2026-02-12 12:26:02Z
- overall_status: PASS

## Checks

| Check | Status | Details | Remediation |
| --- | --- | --- | --- |
| Node version >= 20.19.0 | PASS | detected=v25.3.0 | Install Node.js >= 20.19.0 |
| OpenSpec CLI available | PASS | version=1.1.1 | Run: npm install -g @fission-ai/openspec@latest |
| Path exists: .trellis/spec/guides/constitution.md | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\.trellis\spec\guides\constitution.md | Regenerate or restore missing workflow asset. |
| Path exists: .trellis/spec/guides/memory-governance.md | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\.trellis\spec\guides\memory-governance.md | Regenerate or restore missing workflow asset. |
| Path exists: .codex/skills | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\.codex\skills | Regenerate or restore missing workflow asset. |
| Path exists: .codex/skills/memory-context/SKILL.md | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\.codex\skills\memory-context\SKILL.md | Regenerate or restore missing workflow asset. |
| Path exists: openspec/specs | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\openspec\specs | Regenerate or restore missing workflow asset. |
| Path exists: scripts/verify-ci.ps1 | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\scripts\verify-ci.ps1 | Regenerate or restore missing workflow asset. |
| Path exists: scripts/collect-metrics.ps1 | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\scripts\collect-metrics.ps1 | Regenerate or restore missing workflow asset. |
| Path exists: scripts/memory-context.ps1 | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\scripts\memory-context.ps1 | Regenerate or restore missing workflow asset. |
| Path exists: scripts/workflow-policy-gate.ps1 | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\scripts\workflow-policy-gate.ps1 | Regenerate or restore missing workflow asset. |
| Path exists: scripts/workflow-indicator-gate.ps1 | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\scripts\workflow-indicator-gate.ps1 | Regenerate or restore missing workflow asset. |
| Path exists: workflow-policy.json | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\workflow-policy.json | Regenerate or restore missing workflow asset. |
| Path exists: xxx_docs/00-index.md | PASS | E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\xxx_docs\00-index.md | Regenerate or restore missing workflow asset. |
| OpenSpec active changes readable | PASS | active_changes=0 | Ensure openspec structure exists and is readable. |
| Verify telemetry present | PASS | path=E:\docc\trellis-worktrees\sbk-codex-strict-plan13-philosophy\.metrics\\verify-runs.jsonl | Run: npm run verify:fast or npm run verify:ci |
| Workflow policy gate healthy | PASS | passed | Run: npm run workflow:policy and fix reported policy violations. |
| Workflow indicator gate healthy | PASS | passed | Run: npm run metrics:collect then npm run workflow:gate and remediate threshold failures. |
