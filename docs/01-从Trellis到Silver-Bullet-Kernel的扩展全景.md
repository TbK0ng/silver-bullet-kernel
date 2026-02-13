# 从 Trellis 到 Silver Bullet Kernel 的扩展全景

## 1. 背景：这不是“另一个脚手架”，而是工作流内核

`silver-bullet-kernel` 不是推翻 Trellis，而是在 Trellis 之上补齐“工程级可用性闭环”：

- 从“能跑”升级到“可治理、可审计、可恢复”。
- 从“靠习惯执行流程”升级到“策略即代码（policy-as-code）”。
- 从“靠感觉改进流程”升级到“指标驱动改进”。

对应工程哲学来自 `E:\docc\ai-coding-workflow-silver-bullet-plan.md` 的三条主线：

1. 产物是唯一真相源。
2. 上下文是缓存。
3. 执行是可重入状态机。

## 2. Trellis 原本提供了什么

在本项目基线里，Trellis 主要负责：

- 会话与规范注入（`.trellis/`、`/trellis:start`、`/trellis:record-session`）。
- 工作流指导与质量守则（`.trellis/spec/guides/`）。
- 多 agent、任务与协作辅助（Trellis 自带脚本体系）。

这解决了“有流程”问题，但还不够解决“流程一定被执行且可验证”。

## 3. Silver Bullet Kernel 新增了什么

下面是核心扩展能力（按“问题 -> 方案 -> 代码入口”）：

| 问题 | SBK 扩展方案 | 关键入口 |
| --- | --- | --- |
| 流程靠自觉，容易绕过 | 增加强制治理门禁（policy gate） | `scripts/workflow-policy-gate.ps1`, `workflow-policy.json` |
| 验证执行后难复盘 | 验证遥测与失败诊断留痕 | `scripts/common/verify-telemetry.ps1`, `scripts/verify-*.ps1` |
| 失败后反复重试无结构 | 有界 verify/fix 循环 | `scripts/verify-loop.ps1` |
| 指标改进缺少统一视图 | 周报/快照/阈值门禁 | `scripts/collect-metrics.ps1`, `scripts/workflow-indicator-gate.ps1` |
| 环境坏了不知道先修哪 | 一键健康诊断 | `scripts/workflow-doctor.ps1`, `scripts/workflow-doctor-json.ps1` |
| AI 上下文注入太重/不可审计 | 渐进式记忆检索 + 审计日志 | `scripts/memory-context.ps1` |
| 重命名重构容易误改 | TypeScript 语义重命名 | `scripts/semantic-rename.ts` |
| 可用性没有最小实证 | appdemo API + 冒烟测试 | `src/app.ts`, `scripts/appdemo-smoke.ps1`, `tests/e2e/app.e2e.test.ts` |

## 4. 关键设计变化（你最需要知道的）

## 4.1 治理门禁前置到 `verify`

`verify:fast`、`verify`、`verify:ci` 都先执行策略门禁，再跑 lint/typecheck/test/build。  
这意味着“流程违规”会在最前面失败，而不是拖到最后。

## 4.2 分支/工作树/变更包被绑定为一个整体

策略文件明确要求：

- 分支名必须符合 `sbk-<owner>-<change>`。
- `<change>` 必须和当前 active change 一致。
- 本地实现必须在 linked worktree 中进行。
- 非 trivial 变更要映射到 `openspec/changes/<change>/` 产物。

这让“谁在做什么、是否按约束执行”变得可自动检查。

## 4.3 会话证据成为硬约束

对实现类变更，策略会检查：

- `.trellis/workspace/<owner>/` 下是否有会话证据。
- 会话证据是否包含三个披露标记：
  - `Memory Sources`
  - `Disclosure Level`
  - `Source IDs`

这让上下文来源可追溯，避免“AI 说过但找不到证据”。

## 4.4 报告产物迁移到 `.metrics/`

本项目已把运行时生成物统一迁移到 `.metrics/`，例如：

- `workflow-policy-gate.md/json`
- `workflow-indicator-gate.md/json`
- `workflow-doctor.md/json`
- `workflow-metrics-weekly.md/json`
- `verify-runs*.jsonl`
- `memory-context-audit.jsonl`
- `codebase-map.md`

为什么要迁移：

1. 这些是“运行时报告”，不是长期知识文档。
2. 频繁变动的报告不应污染长期文档目录和历史。
3. 清理测试产物更简单，仓库更干净。

一句话：`xxx_docs/` 放“长期可读知识”，`.metrics/` 放“短期可再生证据”。

## 5. 工程哲学到实现的映射

| 工程哲学 | 落地实现 |
| --- | --- |
| 产物是唯一真相源 | OpenSpec 变更包（proposal/design/tasks/spec delta）+ policy gate 强制映射 |
| 上下文是缓存 | `memory:context` 仅按需注入（index/detail），并记录审计日志 |
| 执行是可重入状态机 | `verify:loop` 失败后自动采样诊断，保留结构化证据可继续修复 |

## 6. 什么叫“可用性闭环达成”

当你能稳定完成下面链路，就说明内核可用：

1. 在正确分支和 worktree 上实现变更。
2. Active change 产物完整且任务证据可读可验。
3. `npm run verify` 通过。
4. `npm run metrics:collect` 产出指标快照。
5. `npm run workflow:gate` 对指标给出通过/告警/失败结论。
6. `npm run workflow:doctor` 显示整体健康。
7. 会话结束有证据记录，可被后续会话恢复。

这就是“完全吻合 + 可用性闭环”的工程定义。
