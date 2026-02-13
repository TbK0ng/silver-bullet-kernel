# Migrate Specs

Sync delta specs from an active OpenSpec change into canonical `openspec/specs` files.

## Usage

```text
/trellis:migrate-specs [--change <change-id>] [--apply]
```

## Source of Truth

1. `openspec/changes/<change-id>/specs/*/spec.md` (delta specs)
2. `openspec/specs/*/spec.md` (canonical specs)
3. `openspec/changes/<change-id>/tasks.md` (evidence and progress)

---

## Execution Flow

1. Resolve target change:
   - if user passes `--change`, use it
   - otherwise infer from active change context or `openspec list --json`
2. Preview migration plan:

```bash
npm run sbk -- migrate-specs --change <change-id>
```

3. Apply migration:

```bash
npm run sbk -- migrate-specs --change <change-id> --apply
```

4. Validate specs:

```bash
openspec validate --all --strict --no-interactive
```

5. Update task evidence and document any remaining manual merge follow-ups.

---

## Output Format

```markdown
## Specs Migration Plan
- [create|update] <capability>: <delta-path> -> <target-path>

## Apply Result
- migrated files: N
- validation: pass/fail

## Follow-ups
- <none or explicit manual reconciliation notes>
```
