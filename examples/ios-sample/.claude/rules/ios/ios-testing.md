---
description: iOS test discipline -- XCTest, XCUITest, Maestro, fakes, Clock injection.
paths: "**/*.swift"
---

# iOS Testing

Tests on iOS span three layers: unit (XCTest / Swift Testing),
UI regression (XCUITest), and agent-driveable E2E (Maestro).
Each has a job; using one where another fits produces slow,
flaky, or weakly-asserting tests. When a rule is unclear, see
`platforms/ios/docs/ios-testing-details.md`.

## Unit tests -- XCTest / Swift Testing

- Target: pure logic, ViewModels, use cases, repositories with
  a fake transport. NEVER hit the real network or filesystem
  in a unit test.
- Frameworks: `XCTest` for legacy targets; the new `Testing`
  framework (`@Test`, `#expect`) for new code on iOS 17+ / Xcode
  16+.
- `async` test methods are first-class. NEVER use semaphores or
  `XCTWaiter` to block for async work -- just `await` it.
- Run via `xcodebuild test` in CI; fast feedback locally via
  `swift test` for SwiftPM packages.

## SwiftUI previews as snapshot seeds

- Treat `#Preview` declarations as snapshot-test seeds. A screen
  with five previews can be wired to a snapshot library
  (swift-snapshot-testing, etc.) for visual regression.
- Previews MUST stand alone -- they cannot depend on a real
  network. That's what makes them usable as snapshot fixtures.

## UI tests -- XCUITest

- XCUITest for code-owned, signed-in-as-test-user regression
  flows. Drives the app via the accessibility tree, runs on
  simulator or device.
- Identify elements by `accessibilityIdentifier` (NOT by visible
  label). Labels change with localization; identifiers are
  stable contracts.
- Disable animations in the test target (`UIView.setAnimationsEnabled(false)`
  in test setup) for determinism.

## E2E -- Maestro

- Maestro YAML flows for agent-driveable E2E. The flows live
  in-repo (`.maestro/`), are checked in, and are the source of
  truth for "what a smoke run looks like."
- Use Maestro for: high-level smoke (cold-launch + login + key
  screen), agent regression runs, post-deploy verification.
- Use XCUITest for: detailed assertions that need access to the
  accessibility tree at granular level, performance metrics.

## Fakes over mocks at boundaries

- Define a protocol at each boundary; provide a `Fake...`
  conforming type for tests. Mocks-via-framework (OCMock-style
  call expectations) are NOT the default.
- A fake records calls in a property the test inspects after
  the act; it does not "verify expectations were met" via a
  brittle expectations API.
- Fakes encode the SAME behavior contract the real does:
  invariants, ordering, idempotency. Tests of the contract
  apply equally to fake and real.

## Time control -- inject a Clock

- ANY code that depends on wall-clock time MUST take a clock
  abstraction. iOS 17+ has `Clock` and `ContinuousClock` as
  protocols; for earlier targets, define a `protocol Clock {
  var now: Date { get } func sleep(for: Duration) async throws
  }`.
- In production, inject `ContinuousClock()` or `SystemClock()`.
  In tests, inject a `TestClock` that advances on command.
- Eliminates `sleep`-based polling in tests entirely.

## Why this discipline matters

The point of tests at the unit + UI + E2E layers is to make
regressions visible BEFORE merge. Slow tests get skipped; flaky
tests get ignored. Fakes-over-mocks and Clock injection keep
unit tests fast and deterministic; Maestro keeps the smoke run
agent-drivable; XCUITest covers the targeted regressions.
