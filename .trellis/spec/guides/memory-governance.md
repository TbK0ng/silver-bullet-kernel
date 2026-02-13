# Memory Governance

## Goal

Keep memory useful, auditable, and safe for a coding workflow project.

## Memory Sources

- Trellis workspace journals under `.trellis/workspace/`
- OpenSpec artifacts under `openspec/`
- Project runbooks under `docs/`

## Injection Rules

- Inject only relevant artifacts for current change scope.
- Prefer concise summaries and links to source files.
- Do not inject full historical journals unless current task requires them.
- Default to progressive disclosure:
  1. index sources first (`npm run memory:context -- -Stage index`)
  2. fetch selected details by ID (`npm run memory:context -- -Stage detail -Ids ...`)

## Retention Rules

- Keep short-lived operational logs in local `.metrics/` (gitignored).
- Keep durable knowledge in versioned docs/specs.
- Keep archived OpenSpec changes as audit trail.
- Keep memory retrieval audit in `.metrics/memory-context-audit.jsonl`.

## Sensitive Data Rules

- Never store secrets in journals/specs/docs.
- Redact tokens, credentials, and private endpoints before recording.

## Session Close Protocol

At end of meaningful work session:

1. Record session with `/trellis:record-session` or equivalent journal update.
2. If a new stable rule is discovered, update:
   - `.trellis/spec/guides/*` (execution policy), or
   - `docs/*` (operational guidance).
3. For owner-scoped session evidence files, include disclosure metadata markers:
   - `Memory Sources`
   - `Disclosure Level`
   - `Source IDs`

## CI Evidence Rule

- For implementation changes, branch delta must include session evidence under `.trellis/workspace/`.
- Session evidence must align with branch owner path: `.trellis/workspace/<owner>/`.
- Keep entries concise and factual: change id, decisions, failures, and verify evidence.
- Policy gate enforces session disclosure metadata markers when owner session evidence is present.
