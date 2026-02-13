# Migration System

> Versioned migration guidance for Trellis template/runtime assets used by SBK.

---

## Purpose

The migration system handles safe template path changes across versions, including:

- file rename
- directory rename
- file removal

It keeps user-modified files protected through hash-based change detection.

---

## Manifest Location

- Source manifests: `src/migrations/manifests/<version>.json`
- Built manifests: `dist/migrations/manifests/<version>.json`

Each release that changes managed template paths should include a manifest.

---

## Manifest Shape

```json
{
  "version": "0.3.0",
  "description": "Move command files under trellis namespace",
  "migrations": [
    {
      "type": "rename",
      "from": ".claude/commands/parallel.md",
      "to": ".claude/commands/trellis/parallel.md",
      "description": "Namespace command files"
    }
  ]
}
```

Supported `type` values:

- `rename`
- `rename-dir`
- `delete`

---

## Safety Rules

- Auto-apply only when target file was not user-modified.
- Prompt or skip when hash indicates user changes.
- Detect source/target conflicts and require manual resolution.
- Keep operations idempotent across repeated update runs.

---

## Validation Checklist

Before release:

1. Manifest exists for versioned path changes.
2. Build step includes manifest files in `dist/`.
3. Upgrade path tests pass from older supported versions.
4. `trellis update --migrate` executes without unexpected conflicts.

---

## Related Files

- `src/types/migration.ts`
- `src/migrations/index.ts`
- `src/utils/template-hash.ts`
- `src/commands/update.ts`
