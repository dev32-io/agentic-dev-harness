# npm Scripts -- Details & Examples

This file expands `platforms/node/rules/npm-scripts.md`.

## A canonical `scripts` block

```json
{
    "scripts": {
        "dev":         "tsx watch src/main.ts",
        "build":       "tsc -p tsconfig.build.json",
        "start":       "node ./dist/main.js",
        "lint":        "eslint .",
        "lint:fix":    "eslint . --fix",
        "format":      "prettier --write .",
        "typecheck":   "tsc --noEmit",
        "test":        "node --test 'src/**/*.test.ts'",
        "test:live":   "node --test 'tests/live/**/*.test.ts'",
        "clean":       "rm -rf dist coverage .tsbuildinfo",
        "check":       "npm run lint && npm run typecheck && npm run test"
    }
}
```

Notes:
- Each `lint` / `typecheck` / `test` runs ONE thing.
- `check` is the only script that chains; it is named so callers
  opt in explicitly. CI runs the three named scripts separately
  (so logs and failures are isolated), not `check`.

## CI calling scripts by name

```yaml
# .github/workflows/ci.yml
name: ci
on: [push, pull_request]
jobs:
    build:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4
            - uses: actions/setup-node@v4
              with:
                  node-version-file: .nvmrc
                  cache: npm
            - run: npm ci
            - run: npm run lint
            - run: npm run typecheck
            - run: npm run test
            - run: npm run build
```

Each step is named, each step's logs are isolated, each step can
fail independently. A reviewer reading the CI log can tell which
of lint/typecheck/test failed without parsing one combined dump.

## Live tests run on a schedule

```yaml
# .github/workflows/nightly.yml
name: nightly
on:
    schedule:
        - cron: "0 5 * * *"
jobs:
    live:
        runs-on: ubuntu-latest
        environment: test-live
        steps:
            - uses: actions/checkout@v4
            - uses: actions/setup-node@v4
              with:
                  node-version-file: .nvmrc
            - run: npm ci
            - run: npm run test:live
              env:
                  TEST_LIVE_API_KEY: ${{ secrets.TEST_LIVE_API_KEY }}
```

Live tests rely on real services (a real database, a real API).
They run nightly so they don't block every PR but DO catch the
"the third-party API changed" class of bug.

## The `&&` anti-pattern

```json
// WRONG.
{
    "scripts": {
        "test": "eslint . && tsc --noEmit && node --test"
    }
}
```

The developer who runs `npm run test` wanted unit tests; they
got the lint+typecheck cost too. The CI step labeled "test"
fails for any of three reasons, and the log conflates them.

```json
// RIGHT.
{
    "scripts": {
        "lint":      "eslint .",
        "typecheck": "tsc --noEmit",
        "test":      "node --test"
    }
}
```

CI runs the three; a developer runs the one they need.

## Pre/post hooks -- the surprise factor

```json
// SURPRISING.
{
    "scripts": {
        "pretest":  "npm run lint",
        "test":     "node --test",
        "posttest": "npm run typecheck"
    }
}
```

A developer running `npm run test` got three things; the log
shows them all under "test." Worse: a CI step that calls `npm
run test` and expects to measure unit-test time now also
measures lint time.

Better:

```json
{
    "scripts": {
        "test": "node --test",
        "check": "npm run lint && npm run typecheck && npm run test"
    }
}
```

`check` is opt-in; nothing implicit happens.

## What `npm test` does

`npm test` is special-cased: it runs the `test` script. So is
`npm start`. So is `npm run` (which lists scripts). Everything
else needs the `run` verb: `npm run lint`. Documented anywhere
this could confuse a newcomer.

## A real script that needs composition

Sometimes a script genuinely needs to do two things sequentially
(e.g. clean THEN build). Two options:

```json
// 1. Explicit named composition -- preferred.
{
    "scripts": {
        "clean":           "rm -rf dist",
        "build":           "tsc -p tsconfig.build.json",
        "rebuild":         "npm run clean && npm run build"
    }
}
```

The `rebuild` name signals to the caller that two things will
happen. Anyone running `npm run build` gets only `tsc`.

```json
// 2. Parallel composition with a helper.
{
    "scripts": {
        "check": "npm-run-all --parallel lint typecheck test"
    }
}
```

Faster on multi-core hardware; isolated logs per child.

## Why script discipline beats Makefile

Some teams reach for a Makefile to escape `package.json`. Both
can work. The argument for staying inside `scripts`:

- Editors and JetBrains IDEs autocomplete from `scripts`.
- `npm run` lists them.
- New contributors look in `package.json` first.

The argument for a Makefile:

- Multi-target dependency graphs.
- Truly polyglot repos (Node + Python + Rust in one tree).

Either is acceptable; what matters is that one of them is the
single source of truth and the team uses it.

(PRs welcome to deepen this platform.)
