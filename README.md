# Silver Bullet Kernel

Codex-first workflow kernel for brownfield development, built on:

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
- `npm run verify:ci` CI-equivalent gate
- `npm run dev` run appdemo server
- `npm run demo:smoke` run appdemo usability smoke test
- `npm run map:codebase` generate codebase map into `xxx_docs/generated/`

## Appdemo API

- `GET /health`
- `GET /api/tasks`
- `POST /api/tasks` with body `{ "title": "..." }`
- `PATCH /api/tasks/:id` with body `{ "title"?: "...", "done"?: boolean }`

## Workflow Contract

1. Start with Trellis context (`/trellis:start`).
2. Track each non-trivial change in `openspec/changes/<name>/`.
3. Implement and verify with project scripts.
4. Archive completed changes to `openspec/changes/archive/`.
5. Record sessions via `/trellis:record-session`.

## Documentation

Project-owned documentation is in `xxx_docs/`.
