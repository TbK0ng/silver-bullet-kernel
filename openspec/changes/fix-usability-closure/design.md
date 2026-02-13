## Context

The workflow kernel enforces strict policy gates. Usability regressions are only
acceptable when they represent intentional policy failures, not accidental script
or command drift.

## Design Decisions

### 1) Memory context must degrade gracefully outside branch-naming contract

- Keep branch-derived change inference as a best effort.
- Treat missing branch-derived change id as empty input, not as a fatal argument-binding error.
- Preserve staged retrieval (`index/detail`) and audit write behavior unchanged.

### 2) Verification entry points must ignore non-project runtime artifacts

- Add `.venv/**` to ESLint ignore list.
- Keep strict lint policy (`--max-warnings=0`) unchanged.

### 3) Command semantics must map 1:1 with docs

- `workflow:policy` remains policy gate.
- `workflow:gate` must invoke indicator gate script directly.

### 4) Doctor diagnostics must follow current docs topology

- Replace legacy `xxx_docs/00-index.md` health check target with `xxx_docs/README.md`.
- Keep doctor behavior and output format unchanged.

### 5) CI governance should validate branch policy in PR flow

- Keep strict `verify-ci` on pull requests.
- Avoid running branch-pattern-constrained `verify-ci` on `push` to `main`.

### 6) Generated workflow diagnostics must stay in ephemeral metrics storage

- Move workflow doctor/policy/indicator report outputs from `xxx_docs/generated/` to `.metrics/`.
- Move metrics collector outputs (`workflow-metrics-weekly.md`, `workflow-metrics-latest.json`) to `.metrics/`.
- Move codebase map output from `xxx_docs/generated/codebase-map.md` to `.metrics/codebase-map.md`.
- Keep `xxx_docs/` as durable guidance docs, not runtime artifact sink.
- Keep policy ignore semantics aligned with `.metrics/`-scoped ephemeral artifacts.

## Verification Strategy

- Run lint/typecheck/unit+e2e/build.
- Run `memory:context` in non-`sbk-*` branch context.
- Run policy and indicator gates.
- Run OpenSpec strict validation.
- Confirm docs and command mapping consistency.
- Confirm generated report files are emitted under `.metrics/` and `xxx_docs/generated/*` is removed from tracked files.
