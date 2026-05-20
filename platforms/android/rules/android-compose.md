---
description: Jetpack Compose -- Compose Compiler plugin, pure composables, state hoisting, effects, strong-skipping, edge-to-edge, adaptive layouts.
paths: "**/*.kt,**/*.kts"
---

# Jetpack Compose

The Compose runtime relies on purity, identity, and stability to skip work.

## Compose Compiler plugin — mandatory with Kotlin 2.0+

- Apply `org.jetbrains.kotlin.plugin.compose` per Compose module, version-matched to Kotlin.
- DELETE any legacy `composeOptions { kotlinCompilerExtensionVersion = ... }` block.

## Pure composables + state hoisting

- `@Composable` body has NO side effects; use `LaunchedEffect` / `DisposableEffect` / `SideEffect`.
- `remember { }` survives recomposition; `rememberSaveable { }` survives process death.
- Stateless components take `state: T` + `onEvent: (Event) -> Unit`. Screen-level composables read VM via `hiltViewModel()`. NEVER reference a ViewModel in a leaf composable.

## Effects, stability, previews

- `LaunchedEffect(key)` — keyed coroutine; `DisposableEffect(key)` — setup+teardown; `SideEffect` — every recomposition.
- Strong-skipping (Compose Compiler 2.0+): all restartable composables are skippable. `@Stable` / `@Immutable` still pay off for cross-module types. Inspect via `metricsDestination` / `reportsDestination`.
- Every screen-level composable needs a `@Preview` (one per state). Use `@PreviewLightDark` + `@PreviewFontScale` for production screens.

## Edge-to-edge (A5)

- Call `enableEdgeToEdge()` before `setContent`; targetSdk 35+ enforces it.
- Theme: `Theme.Material3.DayNight.NoActionBar`. NEVER `@android:style/Theme.Material.*`.

## Adaptive layouts (G3)

- Read `WindowSizeClass`; branch on Compact/Medium/Expanded.
- `NavigationSuiteScaffold` (Material3 adaptive) auto-switches nav bottom/rail/drawer.

See `platforms/android/docs/android-compose-details.md`.
