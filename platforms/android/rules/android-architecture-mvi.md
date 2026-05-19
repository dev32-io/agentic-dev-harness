---
description: MVI architecture -- UiState/Intent/Effect, single source of truth per screen.
paths: "**/*.kt,**/*.kts"
---

# MVI Architecture

MVI (Model-View-Intent) gives every screen a single source of
truth and a single mutation entry point. Reasoning about a
screen reduces to: "what's the current `UiState`, and what
`Intent` produced it?" When a rule is unclear, see
`platforms/android/docs/android-architecture-mvi-details.md`.

## The three types per screen

- `UiState` -- a `data class` (or `sealed` if the screen has
  fundamentally different shapes) holding everything the view
  needs to render. Single source of truth for the screen.
- `Intent` -- a `sealed interface` enumerating user actions and
  external events the screen handles. Adding a new behavior =
  adding a variant.
- `Effect` -- a `sealed interface` for one-shot side effects
  (navigation, snackbar, share-sheet). Effects are NOT state and
  MUST NOT be modeled inside `UiState`.

## ViewModel shape

- `state: StateFlow<UiState>` -- exposed read-only via
  `_state.asStateFlow()`.
- `effects: SharedFlow<Effect>` -- exposed read-only via
  `_effects.asSharedFlow()`. Replay 0, extra-buffer-capacity 1.
- `dispatch(intent: Intent): Unit` -- the only mutation entry
  point. Composables call `dispatch(...)`; nothing else mutates.
- Reduce in a `when (intent) { ... }` block (exhaustive over the
  sealed type). Side work goes into `viewModelScope.launch`.

## Consumption in Composables

- Read state via `collectAsStateWithLifecycle()` -- the lifecycle-
  aware variant pauses collection when the screen is not
  STARTED, preventing wasted work on backgrounded screens.
- Collect effects in a `LaunchedEffect(Unit) { vm.effects.collect { ... } }`
  with a `when` that handles each Effect variant.
- Composables MUST NOT mutate state directly. They send an
  `Intent` via `viewModel.dispatch(...)`.

## What goes where

- Business logic, validation, transformations -- in the reducer
  or in `suspend` functions the ViewModel calls. NEVER in
  composables.
- I/O -- in a repository / use-case, behind an interface, called
  from the ViewModel.
- Theme, layout, formatting strings -- in the composable.
- Navigation -- as an `Effect`; the screen's parent collects and
  acts.

## Why this discipline matters

Without a single mutation entry point, screens drift toward
"any composable can call any setter," and the state machine
becomes invisible. With MVI, a code reader can answer "how do I
get this screen into state X?" by reading the `Intent` sealed
type and the reducer -- nothing else. Tests target the reducer
directly: pass `(state, intent)` and assert `state'`.
