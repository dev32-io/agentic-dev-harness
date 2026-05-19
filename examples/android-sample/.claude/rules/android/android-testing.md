---
description: Android test discipline -- unit/Compose/instrumented/E2E layers, fakes over mocks.
paths: "**/*.kt,**/*.kts"
---

# Android Testing

Four test layers, each with a clear job. Picking the wrong layer
means tests that are either too slow to run often or too fast to
catch the bug class they should. When a rule is unclear, see
`platforms/android/docs/android-testing-details.md`.

## Layer 1 -- unit tests (JVM)

- Target: ViewModels, reducers, pure use-cases, mappers,
  parsers. Anything with no Android-framework dependency.
- Run on the local JVM (`src/test/java/`). No emulator. Fast.
- Time control via `kotlinx-coroutines-test`: `runTest { ... }`
  + a `TestDispatcher` (`StandardTestDispatcher` or
  `UnconfinedTestDispatcher`). Use `advanceTimeBy`,
  `advanceUntilIdle`.
- This is the layer that catches reducer bugs and edge cases.
  It should cover the most decisions per second.

## Layer 2 -- Compose UI tests

- Two flavors:
  - `createComposeRule()` -- isolated composable test; no
    Activity, no Hilt. Use for stateless components.
  - `createAndroidComposeRule<HiltTestActivity>()` -- Hilt-
    injected; use for screens that take a `hiltViewModel()`.
- Drive with `onNodeWithText`, `onNodeWithTag`, `onNodeWithContentDescription`.
- Use semantic matchers; don't poke at internals. If you need a
  test tag, add `Modifier.testTag("...")` in the production code.
- For Hilt-injected screens, swap dependencies via
  `@TestInstallIn` (see `android-hilt-di.md`).

## Layer 3 -- instrumented tests (`androidTest`)

- Reserved for things that REQUIRE a real Android runtime:
  Room migrations, DataStore I/O, deep-link / intent handling,
  permission-flow paths, real ContentProvider plumbing.
- Slower than unit tests; gate sparingly. Skip the platform if a
  fake will do.

## Layer 4 -- E2E via Maestro

- Maestro flows live in `qa/android/charters/<charter>/<flow>.yaml`
  and are driven by the QA charter session.
- Promote a reproducible failure from QA to an E2E flow row in
  the feature spec's e2e matrix (driven by `e2e-testing.md`).
- E2E covers the happy path and the critical regressions only.
  Drowning the gate in E2E flows means it stops running.

## Fakes over mocks

- Prefer hand-written `Fake<Interface>` implementations in
  `src/sharedTest/` or `src/test/` for repository-shaped
  dependencies. Fakes are typed, refactor-safe, and reusable.
- Use a mocking framework (MockK) ONLY at adapter boundaries
  (an SDK you don't own, a static-Java collaborator). Don't
  mock your own interfaces -- write a fake.
- A mock that asserts call counts to your own code is a refactor
  trap. A fake that returns canned data is not.

## Naming and assertion discipline

- Test names describe behavior, not method name. Backtick form:
  `` fun `returns NotFound when id is unknown`() ``.
- One assertion per test where reasonable. If you must assert
  multiple invariants, group them under one logical claim.
- Arrange-Act-Assert layout; blank lines separate the phases.

## Why this discipline matters

Tests fall into one of four cost tiers; mixing them up turns a
1-second feedback loop into a 5-minute one. The rules above
push every test toward the cheapest layer that can actually
catch the bug. Fakes over mocks keeps tests from breaking on
refactors that preserve behavior.
