# Silver Bullet Kernel 文档索引

## 文档结构

本目录包含 Silver Bullet Kernel 项目的运维文档，按阅读顺序组织。

### 必读文档（按顺序）

| 序号 | 文档 | 内容 | 预计时间 |
|------|------|------|----------|
| 1 | [00-概览](00-概览.md) | 项目定位、设计思想、架构概览 | 10 分钟 |
| 2 | [01-快速开始](01-快速开始.md) | 环境准备、安装、首次运行 | 5 分钟 |
| 3 | [02-核心概念](02-核心概念.md) | Trellis、OpenSpec、Policy 深入理解 | 15 分钟 |
| 4 | [03-日常工作流程](03-日常工作流程.md) | 每日开发的标准操作流程 | 10 分钟 |
| 5 | [04-变更管理](04-变更管理.md) | OpenSpec 变更生命周期 | 10 分钟 |
| 6 | [05-质量门禁](05-质量门禁.md) | 验证、CI、策略执行 | 10 分钟 |
| 7 | [06-可观测性](06-可观测性.md) | 指标采集、周报生成 | 10 分钟 |
| 8 | [07-多人协作](07-多人协作.md) | worktree 隔离、分支策略 | 5 分钟 |
| 9 | [08-最佳实践](08-最佳实践.md) | 推荐做法和反模式 | 10 分钟 |
| 10 | [09-故障排除](09-故障排除.md) | 常见问题诊断和解决 | 参考用 |

### 自动生成文档

`generated/` 目录包含自动生成的报告：

| 文件 | 生成命令 |
|------|----------|
| codebase-map.md | `npm run map:codebase` |
| workflow-doctor.md | `npm run workflow:doctor` |
| workflow-policy-gate.md | `npm run workflow:policy` |
| workflow-indicator-gate.md | `npm run workflow:gate` |
| workflow-metrics-weekly.md | `npm run metrics:report` |

## 源真分离

```
┌─────────────────────────────────────────────────────────┐
│                     源真分离架构                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  .trellis/spec/guides/  ←─ 执行策略                     │
│         │                                               │
│         │    注入到 AI 上下文                           │
│         ▼                                               │
│  ┌─────────────────┐                                    │
│  │   AI 助手       │                                    │
│  └─────────────────┘                                    │
│         │                                               │
│         │    遵循变更管理                               │
│         ▼                                               │
│  openspec/              ←─ 变更生命周期                 │
│                                                         │
│         │                                               │
│         │    产出运维知识                               │
│         ▼                                               │
│  xxx_docs/              ←─ 运维文档（本目录）           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 快速命令参考

### 验证

```bash
npm run verify:fast              # 快速验证（~10s）
npm run verify                   # 完整验证（~30s）
npm run verify:ci                # CI 等价验证
```

### 策略

```bash
npm run workflow:policy          # 策略门禁
npm run workflow:gate            # 指标门禁
npm run workflow:doctor          # 健康检查
```

### 指标

```bash
npm run metrics:collect          # 采集指标
npm run metrics:report           # 生成周报
npm run metrics:report:last      # 最近 4 周报告
```

### 变更

```bash
openspec new change <name>       # 创建变更
openspec status                  # 查看活跃变更
openspec archive <name> -y       # 归档变更
```

### 秘密扫描

```bash
npm run secret:scan              # 扫描暂存文件
npm run secret:scan:diff         # 扫描差异
npm run secret:baseline          # 更新基线
```

## 新手入门路径

```
Day 1: 阅读概览 + 快速开始
  └─→ 安装环境，运行 verify:fast

Day 2: 阅读核心概念 + 日常工作流程
  └─→ 理解 Trellis 和 OpenSpec

Day 3: 阅读变更管理 + 质量门禁
  └─→ 创建第一个变更

Day 4: 阅读可观测性 + 最佳实践
  └─→ 查看指标，改进工作流

日常: 参考故障排除
  └─→ 遇到问题时查找解决方案
```

## 文档更新

本目录文档应随项目演进持续更新：

1. **实现过程中** - 及时更新相关文档
2. **遇到问题时** - 添加到故障排除
3. **学到经验后** - 添加到最佳实践或 gotchas/
