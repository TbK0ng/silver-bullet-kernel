## 1. OpenSpec Baseline

- [x] 1.1 Create proposal, design, and delta specs for trigger-semantics clarification.

## 2. Core Docs Trigger Semantics Correction

- [x] 2.1 Update `docs/02-功能手册-命令原理与产物.md` with explicit/conditional trigger boundaries.
- [x] 2.2 Update `docs/05-命令与产物速查表.md` to correct `flow run` stage-chain wording.
- [x] 2.3 Update `docs/06-多项目类型接入与配置指南.md` for conditional flow stage semantics and FAQ clarifications.
- [x] 2.4 Update top-level docs with explicit trigger notes and add code-evidence trigger matrix page.

## 3. Practice Docs Full Alignment

- [x] 3.1 Update `docs/practice/00-导航与阅读地图.md` and `docs/practice/01-一页上手-从引入到首轮可运行.md`.
- [x] 3.2 Update `docs/practice/02-场景实战-绿地项目.md`, `docs/practice/03-场景实战-存量项目接管.md`, and `docs/practice/04-能力手册-命令分层与组合策略.md`.
- [x] 3.3 Update `docs/practice/05-相近功能辨析-怎么选与为什么.md`, `docs/practice/06-提示词手册-Codex主线.md`, `docs/practice/08-附录-平台差异与Beta能力.md`, and `docs/practice/09-代码库架构深潜.md`.

## 4. Validation

- [x] 4.1 Run change-level OpenSpec validation.
- [x] 4.2 Run docs sync and fast verify checks; record outcomes in evidence table.

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/clarify-brainstorm-entrypoints-docs/` | Create complete OpenSpec artifact chain for this docs contract correction. | `openspec validate clarify-brainstorm-entrypoints-docs --type change --strict --no-interactive` | Done (2026-02-15) |
| 2.1 | [x] | `docs/02-功能手册-命令原理与产物.md` | Correct trigger semantics for `greenfield`, `flow run`, `new-change`, and `explore`, including high-risk switches. | `rg -n "flow run|new-change|explore|--with-install|--skip-verify|--fleet-roots|git init|fallback|--allow-beta|--force|unsafe-overwrite" docs/02-功能手册-命令原理与产物.md` | Done (2026-02-15) |
| 2.2 | [x] | `docs/05-命令与产物速查表.md` | Fix quick-reference wording for one-command flow and add explicit trigger reference. | `rg -n "一键全流程|flow run|with-install|显式" docs/05-命令与产物速查表.md` | Done (2026-02-15) |
| 2.3 | [x] | `docs/06-多项目类型接入与配置指南.md`, `scripts/sbk.ps1` | Correct `flow run` chaining semantics and add FAQ for explicit brainstorm/explore triggers plus high-risk switches; align CLI help usage string with flow script options. | `rg -n "flow run|with-install|skip-verify|fleet-roots|brainstorm|explore|new-change|FAQ|Q|--allow-beta|--force|unsafe-overwrite" docs/06-多项目类型接入与配置指南.md`; `rg -n -- \"flow run .*allow-beta.*force\" scripts/sbk.ps1` | Done (2026-02-15) |
| 2.4 | [x] | `docs/README.md`, `docs/01-从Trellis到Silver-Bullet-Kernel的扩展全景.md`, `docs/07-命令触发语义对照表.md` | Add explicit trigger boundary summary in top-level docs and a script-evidence trigger matrix page. | `rg -n "显式|trigger|/trellis:start|record-session|explore|--allow-beta|--force|unsafe-overwrite" docs/README.md docs/01-从Trellis到Silver-Bullet-Kernel的扩展全景.md docs/07-命令触发语义对照表.md` | Done (2026-02-15) |
| 3.1 | [x] | `docs/practice/00-导航与阅读地图.md`, `docs/practice/01-一页上手-从引入到首轮可运行.md` | Align first-run guidance with explicit vs conditional trigger semantics. | `rg -n "手动|自动执行|flow run|explore|new-change|with-install" docs/practice/00-导航与阅读地图.md docs/practice/01-一页上手-从引入到首轮可运行.md` | Done (2026-02-15) |
| 3.2 | [x] | `docs/practice/02-场景实战-绿地项目.md`, `docs/practice/03-场景实战-存量项目接管.md`, `docs/practice/04-能力手册-命令分层与组合策略.md` | Correct greenfield/flow command assumptions and explicit lifecycle command meaning. | `rg -n "greenfield|flow run|with-install|new-change|explore|自动|--allow-beta|--force" docs/practice/02-场景实战-绿地项目.md docs/practice/03-场景实战-存量项目接管.md docs/practice/04-能力手册-命令分层与组合策略.md` | Done (2026-02-15) |
| 3.3 | [x] | `docs/practice/05-相近功能辨析-怎么选与为什么.md`, `docs/practice/06-提示词手册-Codex主线.md`, `docs/practice/08-附录-平台差异与Beta能力.md`, `docs/practice/09-代码库架构深潜.md` | Align comparison/prompt/architecture docs with runtime trigger truth and wording boundaries, including beta/overwrite trigger semantics. | `rg -n "flow run|decision-mode|explore|new-change|自动执行|fallback|with-install|skip-verify|--allow-beta|--force|unsafe-overwrite|channel beta" docs/practice/05-相近功能辨析-怎么选与为什么.md docs/practice/06-提示词手册-Codex主线.md docs/practice/08-附录-平台差异与Beta能力.md docs/practice/09-代码库架构深潜.md` | Done (2026-02-15) |
| 4.1 | [x] | `openspec/changes/clarify-brainstorm-entrypoints-docs/**` | Run strict OpenSpec change validation. | `openspec validate clarify-brainstorm-entrypoints-docs --type change --strict --no-interactive` | Done (pass, 2026-02-15) |
| 4.2 | [x] | `docs/**`, `openspec/changes/clarify-brainstorm-entrypoints-docs/tasks.md` | Run docs-sync/verify fast and record final status in evidence rows. | `npm run workflow:docs-sync`; `npm run verify:fast` | Done (docs-sync pass; verify-fast pass, 2026-02-15) |
