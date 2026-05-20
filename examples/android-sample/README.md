# examples/android-sample

Minimal Android (Compose + Hilt + Navigation) project pre-wired with the agentic-dev-harness rule + hook system. Demonstrates the post-install state with a working MVI counter screen.

## What's here

- `MainActivity` declared `@AndroidEntryPoint` + `enableEdgeToEdge()` + Material3 theme.
- `CounterViewModel` (Hilt-injected) with `UiState` / `Intent` / events-in-state pattern.
- `NavHost` with a `@Serializable` route — type-safe Navigation Compose 2.9.x.
- Unit tests under `app/src/test/` (`runTest` + Robolectric Compose).
- Instrumented test under `app/src/androidTest/` (`@HiltAndroidTest` + `createAndroidComposeRule`).
- `.claude/rules/` and `agents/docs/` from `sh install.sh --target . --platforms android`.

## Toolchain

- AGP 8.10.1 / Kotlin 2.1.20 / Compose BOM 2026.05.00 / Hilt 2.56 / Java 21.
- compileSdk = targetSdk = 36; minSdk = 24.
- Compose Compiler Gradle plugin (`org.jetbrains.kotlin.plugin.compose`) applied.
- Gradle 8.11.1 wrapper committed.

**Deviation from plan:** AGP 9.2.0 is incompatible with `kotlin-android` plugin (absorbed into AGP 9.0) and with Hilt 2.56 (uses legacy `BaseExtension` API removed in AGP 9.x). AGP 8.10.1 is the current stable, Hilt-compatible release and is Play-store-shippable. `navigation-compose 2.10.0` was not yet stable at build time; pinned to 2.9.8 (latest stable; type-safe nav available since 2.8.0).

## To build + test locally

```bash
./gradlew assembleDebug
./gradlew testDebugUnitTest
./gradlew lintDebug
./gradlew connectedDebugAndroidTest   # requires emulator/device
```

## Build verification status

Build verified green on this host (May 2026):

| Task | Exit code |
|---|---|
| `assembleDebug` | 0 |
| `testDebugUnitTest` | 0 (4/4 passed) |
| `lintDebug` | 0 |

Toolchain: Java 21 (Homebrew openjdk@21), Android SDK 36 (platforms/android-36), Gradle 8.11.1.

## How it was set up

1. Phase 5 of mobile-rules-overhaul: Compose + Hilt + type-safe Navigation + MVI counter screen.
2. From the harness repo root: `sh install.sh --target examples/android-sample --platforms android`.
3. Verified the harness landed: `.claude/rules/android/`, `.claude/rules/mobile/` (chained), `agents/docs/android/`, `qa/android/oracles.md`, `scripts/quality-gate.sh`.
