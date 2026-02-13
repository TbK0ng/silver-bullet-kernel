## Why

Recent verification exposed usability and governance inconsistencies that break the
"artifact-driven, verifiable workflow" contract in day-to-day use:

- `npm run memory:context -- -Stage index` fails on non-`sbk-*` branches due strict
  parameter binding.
- local verify entry points fail on `.venv` vendor files, making `verify:fast` and
  `verify` unreliable on standard development setups.
- `workflow:gate` script mapping diverges from docs and policy intent (indicator gate).
- `verify:loop` diagnostics reference outdated doctor path assumptions.
- CI trigger strategy conflicts with strict branch governance on `push` to `main`.

## What Changes

1. Fix `memory-context.ps1` branch/change resolution to support non-`sbk-*` branches.
2. Harden lint ignore set to exclude `.venv` runtime artifacts.
3. Align `workflow:gate` npm script with indicator-gate implementation.
4. Update PowerShell doctor script required docs path to current docs entrypoint.
5. Adjust CI workflow trigger behavior to avoid policy conflict on post-merge `main`.
6. Add regression tests for memory-context behavior in non-`sbk-*` branch context.
7. Update docs/runbook references to keep command semantics consistent.

## Impact

- Restores runnable local fast/full verification loops.
- Restores progressive-disclosure memory retrieval usability.
- Removes command semantic drift across docs, scripts, and policy.
- Preserves strict CI governance where it is intended (PR branch validation).
