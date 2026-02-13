# Semantic Rename

Run deterministic TypeScript symbol rename using compiler APIs.

## Dry Run

```bash
npm run refactor:rename -- --file <path> --line <line> --column <column> --newName <name> --dryRun
```

## Apply Rename

```bash
npm run refactor:rename -- --file <path> --line <line> --column <column> --newName <name>
```

## Usage Notes

- Prefer this command over raw text replacement for symbol renames.
- Run `npm run verify:fast` after apply mode.
