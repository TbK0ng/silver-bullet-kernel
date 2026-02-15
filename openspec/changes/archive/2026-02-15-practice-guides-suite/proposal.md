## Why

当前仓库已有文档更偏向功能说明与局部流程，缺少一套“从引入 SBK 到 SBK 接管开发”的连续实战手册。用户需要面向真实操作的命令与提示词级指引，并且要覆盖不同场景、功能组合与相近能力取舍，且让非程序员也能读懂。

## What Changes

- 新增 `docs/practice/` 分层实践文档套件，覆盖从首次引入到稳定接管开发的完整路径。
- 在实践文档中统一提供：场景、前置条件、手动命令、提示词模板、产物位置、成功判定、失败恢复、何时不用。
- 补充 SBK 全量核心能力的“何时使用 + 如何组合 + 常见误用”说明。
- 增加相近功能辨析与优劣评估，降低误选命令导致的返工。
- 采用 `Stable` 主线、`Beta` 附录警示，避免生产路径被实验能力污染。

## Capabilities

### New Capabilities

- 无

### Modified Capabilities

- `workflow-docs-system`: 增加实践指南套件覆盖要求，确保 `docs/practice/` 提供可执行、可恢复、可对比的端到端操作指引。

## Impact

- Affected docs: `docs/practice/**`（新增）。
- Affected OpenSpec artifacts: `openspec/changes/practice-guides-suite/**`（新增变更链路）。
- 不涉及运行时代码、API、依赖版本或执行脚本行为变更。
