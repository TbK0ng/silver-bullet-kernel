# 附录：平台差异与 Beta 能力

主线原则：  
默认按 Codex + Stable 跑。  
只有在明确收益大于风险时才引入 Beta。

---

## 1. 平台能力怎么查看（手动）

```powershell
sbk capabilities
```

它会输出：

- 当前选中的平台
- 各平台是否支持 CLI agents / session / resume / skip permissions
- 平台回续提示（resume hint）

---

## 2. 当前平台能力差异（基于仓库配置）

## 2.1 Codex（主线）

- `manualMode = true`
- `supportsCliAgents = false`
- `supportsSessionIdOnCreate = false`
- `supportsResume = false`

含义：

- 你主要在当前 worktree 继续任务，不依赖 CLI 会话恢复命令。

## 2.2 Claude / OpenCode / Cursor / iFlow（附录范围）

- 某些平台支持 CLI 会话恢复或自动化程度更高。
- 但是否可用，仍以 `sbk capabilities` 运行时输出为准。

---

## 3. 平台切换前检查单

1. 当前 change 和分支命名是否合规。  
2. linked worktree 是否就绪。  
3. `verify:fast` 是否通过。  
4. 目标平台能力差异是否会影响当前流程（特别是 session/resume）。  

---

## 4. Beta 能力边界（重点）

## 4.1 Beta 触发矩阵（显式/条件）

| 触发方式 | 触发类型 | 效果 |
| --- | --- | --- |
| `flow run --channel beta` | 条件触发（参数决定） | flow 会放开 beta 资产能力（allow-beta 语义被打开） |
| `flow run --allow-beta` | 显式高风险触发 | 即使不是 beta 通道，也显式允许使用 beta 资产 |
| `blueprint apply --allow-beta` | 显式高风险触发 | 允许应用 beta 蓝图（如 `monorepo-service`） |

注意：这些触发只影响“可选资产集”，不会额外隐式触发 explore/new-change/record-session 等流程。

## 4.2 什么时候可以考虑 Beta

- 你需要 stable 没有的新能力。
- 有清晰回滚路径。
- 能接受至少两个 PR 周期的观察期。

## 4.3 什么时候不要用 Beta

- 核心生产路径正在高频交付。
- 团队尚未建立稳定的门禁和指标复盘节奏。
- 当前仓仍处于接管初期（intake 尚未稳定通过）。

---

## 5. Beta 启用与回退（手动）

## 5.1 启用示例

推荐（flow 走 beta 通道）：

```powershell
sbk flow run --scenario auto --decision-mode auto --channel beta --target-repo-root .
```

显式放开（在 stable 通道下也允许 beta 资产）：

```powershell
sbk flow run --scenario auto --decision-mode auto --channel stable --allow-beta --target-repo-root .
```

beta 蓝图：

```powershell
sbk blueprint apply --name monorepo-service --allow-beta --target-repo-root . --project-name demo --adapter node-ts
```

## 5.2 回退建议

1. 切回 stable 路径重跑：

```powershell
sbk flow run --scenario auto --decision-mode auto --channel stable --target-repo-root .
```

2. 复跑：

```powershell
sbk verify:ci
npm run metrics:collect
npm run workflow:gate
```

3. 对比 `.metrics/channel-rollout-audit.jsonl` 的通道转换记录。

---

## 6. Codex 主线下的提示词建议

```text
请坚持 Codex + stable 主线执行。除非我明确批准，不要启用 beta 或 beta blueprint。
如果你判断必须启用 beta 才能继续，请先给我：
1) 启用原因
2) 回滚方案
3) 对 verify:ci 和 workflow:gate 的影响预估
在我确认后再执行。
```

---

## 7. 一句话策略

- 能用 stable 解决，就不要上 beta。  
- 能在当前 worktree 完成，就不要依赖平台特定高级会话能力。  
- 能先证明可回滚，再考虑加速。  
