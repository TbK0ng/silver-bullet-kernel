# Unit Test Guidelines

> Testing conventions for SBK workflow runtime and adapters.

---

## Overview

This repository uses Vitest with TypeScript ESM for automated tests under `tests/`.
Runtime scripts are validated with focused e2e tests that execute PowerShell and Python entrypoints through controlled temp repositories.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Conventions](./conventions.md) | Naming, structure, and assertion style | Done |
| [Mock Strategies](./mock-strategies.md) | What to mock and what to keep real | Done |
| [Integration Patterns](./integration-patterns.md) | E2E patterns for scripts and workflow gates | Done |

---

## Quick Reference

```bash
npm run test
npm run test:e2e
npm run verify:fast
```

---

## Scope Notes

- Unit tests: pure TypeScript behavior in `src/` and utility modules.
- E2E tests: workflow scripts under `scripts/` and `.trellis/scripts/`.
- Policy and parity gates must be covered by deterministic pass/fail test cases.

---

**Language**: Documentation should stay in English for tooling consistency.
