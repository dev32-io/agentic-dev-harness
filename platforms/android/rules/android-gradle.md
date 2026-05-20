---
description: Gradle conventions -- version catalog, Kotlin DSL, convention plugins, KSP, R8 + Baseline Profile on release, module-shape catalog.
paths: "**/*.kt,**/*.kts"
---

# Gradle Build Conventions

Build files are production code: typed, single-sourced, modular.

## Version catalog — single source

- ALL versions/libraries/plugins in `gradle/libs.versions.toml`. NO version literals elsewhere.
- Module scripts reference `libs.kotlinx.coroutines`, `alias(libs.plugins.compose.compiler)`, etc.

## Kotlin DSL + convention plugins

- All build scripts `.kts`. NO Groovy `.gradle` for new modules.
- `build-logic/` included build hosts custom Gradle plugins. One convention per module shape.
- Module scripts reduce to "apply convention + declare deps."

## KSP, not KAPT

- Apply `com.google.devtools.ksp` plugin; replace every `kapt(...)` with `ksp(...)`.
- KAPT is on deprecation path; KSP is ~2x faster on incremental.

## Module-shape catalog (G1)

- `:app` — wires DI root. `:feature:<name>` — depends on `:core:*` only; no feature→feature deps.
- `:core:designsystem` theme/tokens, `:core:ui` shared composables, `:core:data` repos+sources.
- `:core:domain` use-cases+models, `:core:testing` fakes+rules. Bottom-up deps only.

## Java / Kotlin version + R8 + Baseline Profile (G2a)

- `compileOptions` sourceCompatibility + targetCompatibility = `VERSION_21`; `jvmTarget = JvmTarget.JVM_21`.
- Release: `isMinifyEnabled = true`, `isShrinkResources = true`.
- Apply `androidx.baselineprofile` in `:app` + `:benchmark`; baseline profile rules ship with APK.

See `platforms/android/docs/android-gradle-details.md`.
