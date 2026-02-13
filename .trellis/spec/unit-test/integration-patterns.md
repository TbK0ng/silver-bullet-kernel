# Integration Test Patterns

> Patterns for validating workflow runtime behavior end-to-end.

---

## Preferred Approach

Use function-level e2e tests with real filesystem fixtures:

1. Create isolated temp repository fixture.
2. Copy only required scripts/config files.
3. Execute entry commands (`powershell -File ...`, `uv run python ...`).
4. Assert exit code, logs/reports, and file outputs.

This keeps tests fast and deterministic while exercising real command wiring.

---

## Standard Flow

```text
Arrange fixture -> Execute command -> Assert outputs -> Cleanup
```

Recommended assertions:

- Exit code is expected (`0` for pass, non-zero for fail).
- Required report files exist (`.metrics/*.json`, `.metrics/*.md`).
- Report payload contains deterministic pass/fail markers.

---

## Workflow Coverage Matrix

| Workflow | Minimum Coverage |
|----------|------------------|
| `workflow-policy-gate` | one pass + one fail scenario |
| `workflow-docs-sync-gate` | trigger/no-trigger and docs-hit/docs-miss |
| `workflow-skill-parity-gate` | parity pass + missing-surface fail |
| multi-agent codex manual mode | start/status manual behavior |
| `sbk` command dispatch | subcommand routing and failure propagation |

---

## Anti-Patterns

- Do not rely on global repo state in tests.
- Do not assert entire console output when a single structured report is sufficient.
- Do not skip cleanup of temp fixtures.
