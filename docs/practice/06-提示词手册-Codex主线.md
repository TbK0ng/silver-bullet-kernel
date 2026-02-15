# 提示词手册（Codex 主线）

这份手册的定位：  
让你用“高质量提示词”稳定驱动 SBK，而不是每次都临场组织语句。

---

## 1. 写提示词的固定骨架

建议每次都按这个顺序写：

1. 目标：你要达到什么结果。
2. 范围：允许改哪些目录，不允许改哪些目录。
3. 执行：要求 AI 执行哪些命令。
4. 约束：stable/beta、strict/balanced、是否可覆盖文件。
5. 输出：你希望最终汇报哪些信息。
6. 触发边界：显式步骤要明确写出来（如 `explore/new-change/record-session`），不要让命令语义含糊。
7. 高风险开关：是否允许 `--force`、`--allow-beta`、`--unsafe-overwrite` 要单独写明授权。

---

## 2. 可复用变量（先填空再发）

- `<repo>`：目标仓路径
- `<adapter>`：`node-ts|python|go|java|rust`
- `<scenario>`：`greenfield|brownfield|auto`
- `<profile>`：`strict|balanced|lite`
- `<change-id>`：OpenSpec 变更 ID
- `<file>` `<line>` `<column>`：语义操作定位
- `flow` 条件阶段开关：`--with-install`、`--skip-verify`、`--fleet-roots`
- `flow` 高风险开关：`--force`、`--allow-beta`

---

## 3. 阶段化提示词模板

## 3.1 首次接入模板

```text
目标：在当前仓完成 SBK 首轮可运行闭环（stable 主线）。
请按顺序自动执行：
1) npm install
2) npm run workflow:doctor
3) 显式触发探索：/trellis:start（或 sbk explore --change <change-id>）
4) sbk flow run --scenario auto --decision-mode auto --channel stable --target-repo-root .
5) sbk verify:fast
6) npm run metrics:collect

要求：
- 每一步失败先做最小修复后继续；
- 不启用 beta；
- 默认不启用 `--force`、`--allow-beta`、`--unsafe-overwrite`；
- 不要把 AI 自动执行理解为命令会隐式触发 explore/new-change；
- 最后输出：通过/失败、关键 .metrics 产物、下一步建议。
```

## 3.2 绿地项目接管模板

```text
目标：把当前仓按绿地路径初始化并交给 SBK 接管。
请自动执行：
1) 显式触发探索：/trellis:start（或 sbk explore --change <change-id>）
2) sbk greenfield --adapter <adapter> --project-name <name> --project-type backend --target-repo-root .
3) sbk blueprint list，并选择 stable 蓝图（优先 api-service）执行 apply + verify
4) sbk flow run --scenario greenfield --decision-mode auto --adapter <adapter> --project-type backend --channel stable --target-repo-root .
5) sbk verify:fast

输出要求：
- 列出新增文件；
- 指出哪些步骤可重复执行、哪些步骤会覆盖文件；
- 说明本次 flow run 哪些阶段触发、哪些未触发（以及条件原因）。
- 给出下一步开发起点建议。
```

## 3.3 存量项目接管模板

```text
目标：在不破坏现有节奏的前提下完成 brownfield 接管评估。
请自动执行：
1) sbk intake analyze --target-repo-root .
2) sbk intake plan --target-repo-root .
3) sbk intake verify --target-repo-root . --profile strict
4) strict 失败时，自动回退到 balanced，再回退到 lite
5) sbk adapter doctor --target-repo-root .
6) sbk verify:fast

输出要求：
- 给出推荐 profile；
- 给出阻塞项 Top5；
- 给出“今天可落地”的最小行动清单。
```

## 3.4 语义重构安全模板

```text
目标：对符号进行低风险重命名。
请自动执行并分步汇报：
1) sbk semantic reference-map --file <file> --line <line> --column <column> --target-repo-root .
2) sbk semantic safe-delete-candidates --file <file> --line <line> --column <column> --target-repo-root .
3) sbk semantic rename --file <file> --line <line> --column <column> --new-name <newName> --dry-run --target-repo-root .
4) 若 dry-run 风险可接受，再执行正式 rename
5) sbk verify:fast

要求：
- 所有风险先解释再落地；
- 输出改动影响面。
```

## 3.5 门禁失败自动恢复模板

```text
目标：修复当前 verify/policy 失败并恢复到可继续开发状态。
请自动执行：
1) sbk verify:loop -- -Profile fast -MaxAttempts 2
2) 汇总下列报告中的失败根因：
   - .metrics/workflow-policy-gate.md
   - .metrics/workflow-docs-sync-gate.md
   - .metrics/workflow-doctor.md
3) 按优先级执行前两项修复
4) 复跑 sbk verify:fast

输出要求：
- 给出“已修复 / 未修复 / 需人工决策”三类列表。
```

## 3.6 规格迁移模板

```text
目标：把 <change-id> 的 delta specs 安全迁移到 canonical specs。
请自动执行：
1) sbk migrate-specs --change <change-id>
2) 先给我预览摘要（新增/修改/删除了哪些 requirement）
3) 在我确认后执行 sbk migrate-specs --change <change-id> --apply
4) 执行 openspec validate --all --strict --no-interactive

要求：
- 默认不要使用 --unsafe-overwrite；
- 失败时输出可回滚路径。
```

---

## 4. 让提示词更稳定的 7 条规则

1. 明确“先分析再执行”还是“直接执行”。  
2. 明确是否允许覆盖文件（例如 blueprint/flow 的 `--force`、migrate-specs 的 `--unsafe-overwrite`）。  
3. 明确是否允许启用 `beta` 或放开 beta 资产（`--allow-beta`）。  
4. 明确失败策略（重试次数、回退 profile 顺序）。  
5. 明确输出格式（要报告什么路径和指标）。  
6. 明确边界（不改哪些目录/文件）。  
7. 明确高风险开关是否授权（`--force`、`--allow-beta`、`--unsafe-overwrite`）。  

---

## 5. 常见坏提示词与改写

### 坏例 1

“帮我把流程跑通。”

问题：目标不清晰，成功标准缺失。

改写：

“请执行 `sbk flow run --scenario auto --decision-mode auto --channel stable --target-repo-root .`，失败自动修复一次，然后输出 `.metrics/flow-run-report.json` 的 status 和失败阶段，并标明哪些阶段因条件未触发。”

### 坏例 2

“顺便把风险也处理一下。”

问题：范围过大，不可控。

改写：

“只执行 intake 三步（analyze/plan/verify），不要改业务代码。输出阻塞项 Top5 和修复优先级。”

---

## 6. 什么时候要停下来人工决策

- AI 建议启用 Beta 才能继续。
- AI 需要覆盖大量已有文件（`--force` / `upgrade` / `--unsafe-overwrite`）。
- AI 识别到策略门禁与项目实际流程冲突。
- AI 发现需要修改安全相关配置或敏感路径。
