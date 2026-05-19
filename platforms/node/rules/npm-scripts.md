---
description: npm scripts -- standard names, CI invokes scripts not raw commands, no inline chaining.
---

# npm Scripts

`package.json` scripts are the public surface of a Node
codebase. CI, developers, and other agents call them by name.
Drift in those names is the first place onboarding goes wrong.
When a rule is unclear, see
`platforms/node/docs/npm-scripts-details.md`.

## Standard script surface

Every Node codebase exposes at least:

| Script        | What it does                                            |
| ------------- | ------------------------------------------------------- |
| `lint`        | Run the linter; exit non-zero on findings.              |
| `typecheck`   | Run `tsc --noEmit` (or equivalent); no emit, just check.|
| `test`        | Run unit tests (mocks/fakes allowed; fast; CI runs).    |
| `test:live`   | Run live tests against real services; CI runs nightly.  |
| `build`       | Produce the deployable artifact.                        |
| `start`       | Run the built artifact (production-style entry).        |

Optional but conventional:

| Script        | What it does                                            |
| ------------- | ------------------------------------------------------- |
| `dev`         | Run in development mode (hot reload, source maps).      |
| `format`      | Run the formatter, write changes.                       |
| `lint:fix`    | Run the linter with autofix.                            |
| `clean`       | Remove build artifacts.                                 |

## CI invokes scripts by name, not raw commands

- `.github/workflows/*.yml` (or equivalent) calls
  `npm run lint`, `npm run typecheck`, `npm run test`. It does
  NOT call `npx eslint` or `tsc --noEmit` directly.
- This means the developer running `npm run test` locally and CI
  are running THE SAME command. Drift between local and CI is a
  major source of "passed locally, failed in CI."

## No `&&` chains inside a single script

- A script does ONE thing. Composition is done by the caller (CI,
  the developer, another script that explicitly calls multiple).
- `"test": "lint && typecheck && test"` is forbidden -- now the
  developer who wanted only the unit tests is paying the lint
  cost too, and the failure mode is conflated.
- For pre-commit-style "run everything", use a dedicated script
  (`"check": "npm run lint && npm run typecheck && npm run test"`)
  -- still avoiding `&&` if possible by using `npm-run-all` /
  `npm exec` parallelism, but at minimum named explicitly.

## Names match expectations across the org

- `test` runs UNIT tests (fast, CI runs on every push).
- `test:live` runs INTEGRATION/E2E tests against real
  services (slow, CI runs on a schedule or pre-release).
- `build` produces an artifact. `start` runs an artifact.
- `dev` is the development entry point.
- The names are not invented per-repo; they match what every
  other Node repo in the org does, so an agent dropping into a
  new repo can run the right command without reading docs.

## Pre/post hooks -- avoid

- npm honors `prelint`, `posttest`, etc. They are seductive and
  surprise the caller -- the agent that runs `npm run lint`
  did not opt into whatever `prelint` does.
- If composition is needed, name it explicitly (`check`, `ci`,
  `release-prepare`) and document it.

## Why this discipline matters

The script surface is a contract. The agent that lands in an
unfamiliar codebase runs `npm run lint` and `npm run test` and
expects them to work. When those names mean something different
in each repo, the agent has to read every `package.json` before
it can do its job. Standardizing the names removes that tax.
