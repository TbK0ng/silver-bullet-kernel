# Test Conventions

> File naming, structure, and assertion patterns for this repository.

---

## Test Infrastructure

| Item | Value |
|------|-------|
| Framework | Vitest |
| Config | `vitest.config.ts` |
| Test root | `tests/` |
| E2E root | `tests/e2e/` |
| Lint command | `npm run lint` |
| Typecheck command | `npm run typecheck` |
| Unit command | `npm run test` |
| E2E command | `npm run test:e2e` |

---

## When to Add Tests

| Change Type | Required Test |
|-------------|----------------|
| Script behavior change (`scripts/*.ps1`) | E2E test for pass and fail paths |
| Multi-agent runtime change (`.trellis/scripts/multi_agent/*.py`) | E2E regression for affected platform modes |
| Policy/parity gate logic change | E2E validation of deterministic gate result |
| Pure utility logic change | Unit test focused on input/output behavior |

---

## Naming Rules

- Unit tests: `tests/<area>/<name>.test.ts`
- End-to-end tests: `tests/e2e/<workflow>.e2e.test.ts`
- Keep names aligned with the workflow or script being verified.

---

## Assertion Rules

- Prefer exact assertions over loose truthy checks.
- Verify observable behavior (exit code, report content, generated files).
- Keep tests deterministic: no network calls, no time-based flakes.

---

## Cleanup Rules

- Use per-test temp directories.
- Always clean temp directories in `afterEach`.
- Restore all mocks using `vi.restoreAllMocks()`.
- Clear global stubs with `vi.unstubAllGlobals()` when used.
