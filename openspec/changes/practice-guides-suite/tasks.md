## 1. OpenSpec Baseline

- [x] 1.1 完成 proposal/design/spec delta，定义实践指南套件范围与验收标准。

## 2. 实践指南主文档编写

- [x] 2.1 新建 `docs/practice/` 导航与一页上手文档，覆盖首轮可运行路径。
- [x] 2.2 新建绿地/存量两类场景实战文档，覆盖命令、提示词、产物与恢复策略。

## 3. 能力辨析与提示词体系

- [x] 3.1 新建命令分层与组合策略手册，覆盖核心 `sbk` 能力。
- [x] 3.2 新建相近功能辨析文档，给出“何时用/何时不用/优劣”。
- [x] 3.3 新建 Codex 主线提示词手册，覆盖开发全流程。

## 4. 治理与附录

- [x] 4.1 新建质量门禁与指标运维文档，说明策略门禁与指标解释。
- [x] 4.2 新建平台差异与 Beta 能力附录，给出安全启用边界。
- [x] 4.3 新增代码库架构深潜文档，建立“命令入口-运行时解析-门禁-指标-OpenSpec/Trellis”的一体化理解路径。

### Task Evidence

| ID | Status | Files | Action | Verify | Done |
| --- | --- | --- | --- | --- | --- |
| 1.1 | [x] | `openspec/changes/practice-guides-suite/proposal.md`, `openspec/changes/practice-guides-suite/design.md`, `openspec/changes/practice-guides-suite/specs/workflow-docs-system/spec.md`, `openspec/changes/practice-guides-suite/tasks.md` | 定义实践指南套件范围、结构、约束与规范增量。 | `openspec validate practice-guides-suite --type change --strict --no-interactive` | 已完成：变更链路创建完毕。 |
| 2.1 | [x] | `docs/practice/00-导航与阅读地图.md`, `docs/practice/01-一页上手-从引入到首轮可运行.md` | 落地导航与首轮可运行操作指引。 | `rg -n "手动命令|提示词模板|成功判定" docs/practice/00-导航与阅读地图.md docs/practice/01-一页上手-从引入到首轮可运行.md` | 已完成：关键章节命中并可检索。 |
| 2.2 | [x] | `docs/practice/02-场景实战-绿地项目.md`, `docs/practice/03-场景实战-存量项目接管.md` | 落地场景化操作手册（greenfield / brownfield）。 | `rg -n "失败恢复|何时不用" docs/practice/02-场景实战-绿地项目.md docs/practice/03-场景实战-存量项目接管.md` | 已完成：场景文档含恢复与禁用边界。 |
| 3.1 | [x] | `docs/practice/04-能力手册-命令分层与组合策略.md` | 汇总命令能力分层、组合链路与产物路径。 | `rg -n "sbk flow run|sbk install|sbk verify:ci" docs/practice/04-能力手册-命令分层与组合策略.md` | 已完成：核心命令与组合链路覆盖。 |
| 3.2 | [x] | `docs/practice/05-相近功能辨析-怎么选与为什么.md` | 形成相近能力选择框架与优劣评估。 | `rg -n "对比|优点|缺点|何时不用" docs/practice/05-相近功能辨析-怎么选与为什么.md` | 已完成：对比与优劣分析落地。 |
| 3.3 | [x] | `docs/practice/06-提示词手册-Codex主线.md` | 提供可复制提示词模板并标注输入/输出预期。 | `rg -n "提示词模板|输出要求|失败先" docs/practice/06-提示词手册-Codex主线.md` | 已完成：阶段化提示词模板覆盖主流程。 |
| 4.1 | [x] | `docs/practice/07-运维与治理-质量门禁与指标.md` | 编写策略门禁、指标解释与故障修复路径。 | `rg -n "workflow:policy|workflow:gate|metrics:collect" docs/practice/07-运维与治理-质量门禁与指标.md` | 已完成：门禁职责与指标解释可执行。 |
| 4.2 | [x] | `docs/practice/08-附录-平台差异与Beta能力.md` | 补充平台能力边界与 Beta 使用注意事项。 | `rg -n "Codex|Claude|Beta|stable" docs/practice/08-附录-平台差异与Beta能力.md` | 已完成：平台差异与 Beta 边界明确。 |
| 4.3 | [x] | `docs/practice/09-代码库架构深潜.md`, `docs/practice/README.md`, `openspec/changes/practice-guides-suite/tasks.md` | 新增代码库架构深潜文档并接入阅读入口，补充 Mermaid 架构总览图、关键调用时序图、失败分支时序图、CI 专用失败回路图，并为每张图增加“读图说明”“常见误读纠偏”与“30 秒排障路径”及 OpenSpec 任务证据。 | `rg -n "架构总览图（Mermaid）|关键调用时序图（Mermaid）|失败分支时序图（Mermaid）|CI 专用失败回路图（Mermaid）|flowchart TD|sequenceDiagram|读图说明|常见误读纠偏|30 秒排障路径|Policy Gate 失败|Docs Sync Gate 失败|Skill Parity Gate 失败|Indicator Gate 失败|CI 失败但本地不复现|OpenSpec 校验失败|strict fail|all fail|any gate fail|policy gate fail|docs-sync fail|skill parity fail|openspec fail|indicator fail|控制面入口|治理门禁层|验证流水线|Trellis / OpenSpec|代码架构与执行链路" docs/practice/09-代码库架构深潜.md docs/practice/README.md openspec/changes/practice-guides-suite/tasks.md` | 已完成：深潜文档含可视化架构图、主/失败/CI 失败回路时序图、读图说明、误读纠偏与 30 秒排障路径，且已纳入实践入口与变更证据。 |
