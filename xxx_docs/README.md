# Silver Bullet Kernel 使用指南

## 这是什么？

这是一个 **AI 辅助编程工作流框架**，帮你解决用 AI 写代码时的几个痛点：

| 痛点 | 解决方案 |
|------|----------|
| AI 每次都忘记之前聊过什么 | 自动保存会话记录，下次恢复 |
| AI 不懂你项目的代码风格 | 配置文件告诉 AI 你的规范 |
| AI 写的代码质量不稳定 | 自动检查门禁，不通过不让提交 |

## 核心概念（3 分钟理解）

### 1. Trellis - 会话管理

```
你的项目/
└── .trellis/
    └── workspace/
        └── 你的名字/
            └── journal-1.md   ← AI 自动记录这轮干了什么
```

每次开始工作：`/trellis:start`（读取之前的记录）
每次结束工作：`/trellis:record-session`（保存这轮的记录）

### 2. OpenSpec - 变更管理

```
你的项目/
└── openspec/
    └── changes/
        └── add-login/         ← 一个功能变更
            ├── proposal.md    ← 为什么要做
            ├── design.md      ← 怎么做
            └── tasks.md       ← 具体步骤
```

**核心流程：** 先写文档想清楚 → 再写代码 → 验证通过 → 归档

### 3. Policy - 规则配置

```
.trellis/policy.yaml   ← 配置你的规则
```

比如：
- 验证失败率超过 50% 就报错
- 返工次数超过 5 次就警告
- 不允许修改 .env 文件

## 快速开始

### 1. 安装依赖

```bash
# Node.js 依赖
npm install

# Python 依赖（用 uv）
uv sync
```

### 2. 验证环境

```bash
npm run verify:fast
```

### 3. 健康检查

```bash
npm run workflow:doctor
```

## 常用命令

### 验证代码

```bash
npm run verify:fast      # 快速检查（lint + typecheck）
npm run verify           # 完整检查（+ test + build）
npm run verify:ci        # CI 完整检查
```

### 工作流管理

```bash
npm run workflow:doctor  # 健康检查
npm run workflow:policy  # 策略检查
npm run workflow:gate    # 指标检查
```

### 指标报告

```bash
npm run metrics:collect  # 采集指标
npm run metrics:report   # 生成周报
```

### 安全扫描

```bash
npm run secret:scan      # 扫描暂存文件中的密钥
```

## 工作流程

### 日常开发

```
1. 开始工作
   git pull
   npm run verify:fast
   /trellis:start

2. 开发中
   写代码...
   npm run verify:fast  # 经常跑

3. 准备提交
   npm run verify
   npm run workflow:policy

4. 结束工作
   /trellis:record-session
```

### 功能开发

```
1. 创建变更
   openspec new change add-login

2. 写设计文档
   编辑 openspec/changes/add-login/proposal.md
   编辑 openspec/changes/add-login/design.md

3. 实现
   写代码...
   更新 tasks.md 记录进度

4. 验证归档
   npm run verify
   openspec archive add-login
```

## 目录结构

```
silver-bullet-kernel/
├── .trellis/              # 工作流配置
│   ├── policy.yaml        # 策略配置
│   ├── scripts/           # 脚本工具
│   ├── workspace/         # 会话记录
│   ├── metrics/           # 指标数据
│   └── gotchas/           # 踩坑记录
├── .claude/               # Claude 配置
│   ├── hooks/             # 自动化钩子
│   └── agents/            # 代理定义
├── openspec/              # 变更管理
│   ├── specs/             # 规格定义
│   └── changes/           # 活跃变更
├── src/                   # 源代码
├── tests/                 # 测试
└── scripts/               # 构建脚本
```

## 6 个核心指标

| 指标 | 含义 | 健康值 |
|------|------|--------|
| Lead Time | 任务完成时间 | < 24 小时 |
| Verify Failure | 验证失败率 | < 20% |
| Rework Count | 返工次数 | < 3 次/周 |
| Parallel Tasks | 并行任务数 | >= 1 |
| Spec Drift | 规格漂移 | = 0 |
| Token Cost | API 成本 | 可追踪 |

## 下一步

- [配置指南](01-配置指南.md) - 详解 policy.yaml 配置
- [命令参考](02-命令参考.md) - 所有命令的详细说明
- [常见问题](03-常见问题.md) - 遇到问题看这里
