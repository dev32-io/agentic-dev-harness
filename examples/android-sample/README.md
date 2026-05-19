# examples/android-sample

Minimal Android (Compose) project pre-wired with the agentic-dev-harness rule + hook system. Demonstrates the post-install state.

## What's here

- Minimal Compose app — single `MainActivity` rendering "agentic-dev-harness android sample" inside `MaterialTheme`.
- Standard Gradle Kotlin DSL build with a version catalog at `gradle/libs.versions.toml`.
- One JVM unit test (`MainActivityTest.smoke`) under `app/src/test/`.
- `.claude/rules/` and `agents/docs/` from `sh install.sh --target . --platforms android` (chain pulls in `mobile`).
- `qa/android/oracles.md` + sample charters under `qa/android/charters/`.

## To run locally

Requires: Android Studio or the Android SDK command-line tools, JDK 17+, and Gradle (or a generated `./gradlew`).

```
gradle wrapper                  # one-time, generates ./gradlew
./gradlew assembleDebug         # build
./gradlew testDebugUnitTest     # tests
sh scripts/quality-gate.sh all  # full gate
```

`scripts/quality-gate.sh` auto-detects this as an Android project (sees `build.gradle.kts` / `settings.gradle.kts`) and dispatches to `./gradlew lintDebug && assembleDebug && testDebugUnitTest`.

## Build verification status

Skipped in the scaffold commit because the harness host did not have `gradle`, the Android SDK, or `./gradlew` available. The sources are syntactically correct standard Compose + version-catalog scaffolding; running `gradle wrapper && ./gradlew assembleDebug` locally is the expected verification path.

## How it was set up

1. Hand-scaffolded a minimal Compose app + Gradle Kotlin DSL + version catalog (no Android Studio required for the source files).
2. From the harness repo root: `sh install.sh --target examples/android-sample --platforms android`.
3. Verified the harness landed: `.claude/rules/android/`, `.claude/rules/mobile/` (chained), `agents/docs/android/`, `qa/android/oracles.md`, `scripts/quality-gate.sh`.
