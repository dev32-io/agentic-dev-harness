---
description: Bun test -- bun test runner, snapshots committed, watch dev-only, no skip/only in CI.
paths: "**/*.test.ts,**/*.spec.ts"
---

# Bun Test

`bun test` is built into the Bun runtime and is the default test
runner for Bun projects. Bringing Jest or Vitest into a Bun
project re-introduces install time, config complexity, and a
slower runner. When a rule is unclear, see
`platforms/bun/docs/bun-test-details.md`.

## `bun test` is the runner

- The `test` script is `bun test`. CI calls `bun test`. The
  developer runs `bun test`. There is no second runner.
- `bun:test` re-exports a Jest-compatible API
  (`describe`/`test`/`expect`); migration from Jest is largely
  search-and-replace of imports.
- Per-file or per-suite configuration uses `bun:test` builtins
  (`beforeAll`, `afterAll`, `beforeEach`, `afterEach`, `mock`).

## Snapshot tests are checked in

- `toMatchSnapshot` produces `*.snap` files next to the test.
  These files ARE source code -- review them in PRs like any
  other change.
- An unintended snapshot diff is a real diff, not noise. A
  reviewer asks: "is this output change intentional?"
- `bun test --update-snapshots` rewrites snapshots. It is run
  intentionally after a deliberate output change, and the diff
  is reviewed before commit.

## Watch mode is developer-only -- NEVER CI

- `bun test --watch` is a dev-loop convenience. CI MUST NOT
  run it (it never exits cleanly; CI would either time out or
  hang).
- The CI script is plain `bun test`. The dev script may be
  `bun test --watch` if the team finds that useful, exposed as
  `test:watch`.

## `.only` and `.skip` are forbidden in checked-in code

- `test.only` makes the entire suite skip everything else.
  Committing it disables the rest of the tests, often without
  the author noticing.
- `test.skip` silently disables a test. If a test should not
  run, delete it (with a comment in the commit message) or fix
  it; do not let it rot.
- CI enforces this with a grep step:

  ```yaml
  - name: forbid test.only / test.skip in checked-in code
    run: |
        if grep -RE '\b(test|it|describe)\.(only|skip)\b' \
            --include='*.test.ts' --include='*.spec.ts' src tests; then
            echo "test.only / test.skip found in checked-in code"
            exit 1
        fi
  ```

  The grep job is fast and fails loudly. It is non-negotiable.

## Test layout -- co-located OR `tests/` -- one choice

- Unit tests: co-located next to the source (`foo.ts` +
  `foo.test.ts`). The proximity makes them likely to be updated
  when the source changes.
- Integration / live tests: under `tests/live/` or `tests/e2e/`,
  out of the unit-test loop. Their CI step is separate (a
  scheduled run, not every push).
- One layout per project, written in the README. Mixing both
  conventions in one repo is the failure mode.

## Why this discipline matters

A test that does not run is a test that lies about coverage. The
guardrails -- no `.only`, no `.skip`, no watch in CI, snapshots
reviewed -- exist because every team that didn't put them in
place re-discovered the same bugs from the wrong direction.
