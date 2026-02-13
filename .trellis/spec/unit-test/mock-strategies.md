# Mock Strategies

> Keep mocks minimal and focused on external dependencies.

---

## Principle

Mock only what is external or non-deterministic:

- process environment surfaces (`process.cwd`, `process.env`)
- shell/process boundaries when needed (`node:child_process`)
- network APIs (if any are touched)

Keep filesystem behavior real in temp directories whenever possible.

---

## Recommended Mock Set

| Dependency | Why Mock |
|------------|----------|
| `console.log/error` | keep test output clean |
| `process.cwd()` | pin test execution root |
| global fetch / network | avoid external instability |
| optional child process wrappers | isolate command construction tests |

---

## What Not to Mock

- Internal business logic modules under test.
- `fs` operations inside isolated temp fixtures.
- Workflow report parsing logic (use real reports).

---

## Good Practices

- Reset mocks in `afterEach`.
- Prefer explicit return values that mirror real API shapes.
- Assert behavior, not implementation details.
