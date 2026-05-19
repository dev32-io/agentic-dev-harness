---
description: Jetpack Compose -- pure composables, state hoisting, effects, previews.
paths: "**/*.kt,**/*.kts"
---

# Jetpack Compose

Compose runs composable functions many times per second. A
composable that lies about its purity recomposes badly, leaks
state, or skips frames. Every rule below protects recomposition
correctness. When a rule is unclear, see
`platforms/android/docs/android-compose-details.md`.

## Pure composables

- A `@Composable` function's body MUST NOT have side effects.
  Network calls, file I/O, mutation of shared state -- none of
  it in the function body.
- Side effects go inside effect APIs (`LaunchedEffect`,
  `DisposableEffect`, `SideEffect`). Compose decides when and how
  often to run them; you don't.
- `Log.d` for debugging is acceptable. Anything observable to the
  user or to another component is not.

## `remember` and `rememberSaveable`

- `remember { ... }` for state that must survive recomposition
  but not configuration change.
- `rememberSaveable { ... }` for state that must also survive
  process death (rotation, language switch, system reclaim).
  The saved value must be `Parcelable`, primitive, or have a
  `Saver`.
- A `remember` without a key is bound to the call site; pass a
  key argument (`remember(id) { ... }`) when the remembered
  value depends on inputs.

## State hoisting

- Stateful composables are leaves. The rest are stateless: they
  take `state: T` and `onEvent: (T) -> Unit` parameters.
- A reusable composable MUST NOT reference a `ViewModel`. Only
  screen-level composables read a VM (via `hiltViewModel()`).
- Lift state to the lowest common ancestor of all readers and
  writers. No lower, no higher.

## Effects -- pick the right one

- `LaunchedEffect(key) { ... }` -- a coroutine that runs when
  `key` enters the composition and cancels when it leaves.
- `DisposableEffect(key) { ...; onDispose { ... } }` -- non-
  coroutine setup with a teardown step (listener registration).
- `SideEffect { ... }` -- runs after every successful
  recomposition. Use for forwarding state to non-Compose code
  (analytics, native handles).

## Stability for skippable composables

- A composable is "skippable" iff its parameters are stable.
  Skippable composables don't recompose when inputs are
  reference-equal to last frame -- the perf win.
- Mark immutable types `@Immutable`; mark types whose equality
  is meaningful but fields may change `@Stable`.
- A `data class` whose fields are all primitives or `@Immutable`
  is stable for free. A `data class` carrying `MutableList` is
  not -- the compiler can't see through mutability.

## Previews are mandatory

- Every screen-level composable MUST have a `@Preview` in the
  same file. Multi-state screens get one preview per state.
- Previews take fake data; they MUST NOT depend on a real VM.
- Use `@PreviewLightDark` and `@PreviewFontScale` for screens
  that ship to production -- they catch theme and a11y bugs
  before the screen ever runs on a device.

## UI tests via `createComposeRule()`

- UI tests use `createComposeRule()` for isolated composable
  tests; `createAndroidComposeRule<HiltTestActivity>()` when the
  test needs DI.
- Drive the test with `onNodeWithText`, `onNodeWithTag`,
  `performClick`, `assertIsDisplayed`. Avoid `Thread.sleep` --
  use `waitUntil` or `mainClock.advanceTimeBy`.

## Why this discipline matters

The Compose runtime relies on purity and stability to skip work.
Side effects in the body and unstable parameters silently turn a
60fps screen into a 30fps one with no error to point at. The
rules above keep the compiler's optimizations on your side.
