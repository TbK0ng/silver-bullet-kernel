# Gotchas Index

> Known issues, pitfalls, and lessons learned from this project.
>
> **Purpose**: Capture failures and solutions so they don't repeat.

---

## How to Use This Directory

1. **When you encounter a problem**, check here first
2. **When you solve a problem**, document it here
3. **When you see a pattern**, create a new gotcha file

---

## Categories

### Development Workflow

| Gotcha | Description | Severity |
|--------|-------------|----------|
| [ai-memory-limits](./ai-memory-limits.md) | AI context window limitations | High |
| [hook-injection-order](./hook-injection-order.md) | Order matters for hook context injection | Medium |
| [jsonl-path-validation](./jsonl-path-validation.md) | JSONL files must reference existing paths | Medium |

### Platform-Specific

| Gotcha | Description | Platform |
|--------|-------------|----------|
| [windows-path-encoding](./windows-path-encoding.md) | Windows path handling quirks | Windows |
| [opencode-agent-naming](./opencode-agent-naming.md) | OpenCode built-in agent name conflicts | OpenCode |

### Integration

| Gotcha | Description | Component |
|--------|-------------|-----------|
| [detect-secrets-baseline](./detect-secrets-baseline.md) | Baseline management for secret scanning | Security |
| [openspec-schema-migration](./openspec-schema-migration.md) | Schema changes require manual migration | OpenSpec |

---

## Quick Reference by Severity

### 🔴 Critical (Blockers)

- **ai-memory-limits**: Always verify context injection, don't assume AI remembers

### 🟡 Warning (Gotchas)

- **hook-injection-order**: Hooks run in order, later hooks can override earlier
- **jsonl-path-validation**: Task won't start if JSONL references missing files

### 🟢 Info (Tips)

- **windows-path-encoding**: Use forward slashes in config files
- **opencode-agent-naming**: Prefix custom agents to avoid conflicts

---

## Contributing

Found a new gotcha? Create a file using this template:

```markdown
# <Gotcha Title>

## Symptoms
What you observe when this happens.

## Root Cause
Why this happens.

## Solution
How to fix or avoid it.

## Prevention
How to prevent it from happening again.

## Related
- Links to related gotchas or docs
```

---

## Statistics

| Metric | Value |
|--------|-------|
| Total Gotchas | 6 |
| Critical | 1 |
| Warning | 2 |
| Info | 3 |
| Last Updated | 2024-02-13 |

---

*Capture failures, share lessons, improve together.*
