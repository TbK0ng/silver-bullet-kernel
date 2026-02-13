# Silver Bullet Kernel

AI 辅助编程工作流框架，基于 Trellis + OpenSpec 构建：

> 专为已有代码库（非从零开始）设计的 AI 编程工作流解决方案

- Trellis for execution policy, context injection, and worktree orchestration
- OpenSpec for artifact-driven change management

## Prerequisites

- Node.js `>=20.19.0`
- npm `>=10`
- OpenSpec CLI installed globally for strict validation in CI/local:
  - `npm install -g @fission-ai/openspec@latest`

## Quick Start

```bash
npm install
npm run verify
```

## Core Commands

- `npm run verify:fast` local fast gate
- `npm run verify` local full gate
- `npm run verify:loop -- -Profile fast -MaxAttempts 2` bounded verify/fix loop with diagnostics evidence
- `npm run verify:ci` CI-equivalent gate
- `npm run dev` run appdemo server
- `npm run demo:smoke` run appdemo usability smoke test
- `npm run refactor:rename -- --file <path> --line <n> --column <n> --newName <name> [--dryRun]` semantic rename
- `npm run memory:context -- -Stage index` progressive-disclosure memory source index
- `npm run map:codebase` generate codebase map into `xxx_docs/generated/`
- `npm run metrics:collect` generate weekly workflow metrics from verify telemetry
- `npm run metrics:token-cost -- -Source <provider> -TotalCostUsd <amount>` publish token-cost summary
- `npm run workflow:policy` enforce workflow policy gate
- `npm run workflow:gate` enforce indicator threshold gate
- `npm run workflow:doctor` run workflow health diagnosis and output report

## Appdemo API

- `GET /health`
- `GET /api/tasks`
- `POST /api/tasks` with body `{ "title": "..." }`
- `PATCH /api/tasks/:id` with body `{ "title"?: "...", "done"?: boolean }`

## Workflow Contract

1. Start with Trellis context (`/trellis:start`).
2. Track each non-trivial change in `openspec/changes/<name>/`.
3. Implement on linked worktree branch `sbk-<owner>-<change>`.
4. Verify with project scripts and policy gates.
5. Archive completed changes to `openspec/changes/archive/`.
6. Record sessions via `/trellis:record-session`.
7. For owner session evidence updates, include `Memory Sources`, `Disclosure Level`, and `Source IDs` markers.

## Documentation

- [使用指南](xxx_docs/README.md) - 快速上手
- [配置指南](xxx_docs/01-配置指南.md) - 配置详解
- [命令参考](xxx_docs/02-命令参考.md) - 所有命令
- [常见问题](xxx_docs/03-常见问题.md) - 故障排除
