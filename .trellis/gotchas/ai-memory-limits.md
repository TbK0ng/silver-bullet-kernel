# AI Memory Limits

## Severity
🔴 **Critical** - Can cause incomplete or incorrect implementations

## Symptoms

- AI implements something that contradicts earlier requirements
- AI forgets project conventions mentioned at session start
- AI reverts to generic patterns instead of project-specific ones
- Code drifts from specs as conversation gets longer

## Root Cause

AI has a limited context window. As conversation grows:
1. Earlier context (including injected specs) gets pushed out
2. AI's attention to earlier instructions decreases
3. AI reverts to generic "pre-trained" patterns

This is not a bug - it's a fundamental limitation of current LLM architecture.

## Solution

### Immediate Fix
Run `/trellis:before-backend-dev` or `/trellis:before-frontend-dev` to re-inject specs.

### During Long Sessions
1. **Checkpoint frequently**: Use `/trellis:check-*` after each major change
2. **Keep prompts concise**: Don't repeat context unnecessarily
3. **Use hooks**: Hooks auto-inject context to subagents

### For Complex Tasks
1. **Use the multi-agent pipeline**: Dispatch + Implement + Check agents each get fresh context
2. **Break into smaller tasks**: Each task gets a new context window
3. **Record decisions in artifacts**: Write important decisions to files, not just chat

## Prevention

| Practice | How |
|----------|-----|
| Use Task Workflow | Creates jsonl context files that hooks auto-inject |
| Check after implement | `/trellis:check-*` re-verifies against specs |
| Record session | `/trellis:record-session` captures learnings for next session |
| Keep specs updated | If you learn something new, update `.trellis/spec/` |

## Code Reference

- Hook: `.claude/hooks/inject-subagent-context.py` - Auto-injects context to subagents
- Check: `.claude/commands/trellis/check-backend.md` - Re-verifies code against specs

## Related

- [hook-injection-order](./hook-injection-order.md) - Order matters for context injection
- [jsonl-path-validation](./jsonl-path-validation.md) - How jsonl files work
