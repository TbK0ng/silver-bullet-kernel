# Memory Context (Progressive Disclosure)

Use staged retrieval instead of full memory injection.

## Stage 1: Index

```bash
npm run memory:context -- -Stage index
```

## Stage 2: Detail

```bash
npm run memory:context -- -Stage detail -Ids S001,S003
```

Audit records are written to `.metrics/memory-context-audit.jsonl`.

When recording owner session evidence, include:

- `Memory Sources`
- `Disclosure Level`
- `Source IDs`
