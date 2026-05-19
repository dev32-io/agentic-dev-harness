---
description: Gradle conventions -- version catalog, Kotlin DSL, convention plugins, R8.
paths: "**/*.kt,**/*.kts"
---

# Gradle Build Conventions

Gradle is the most-edited build system in Android, and the
most-misused. Treat the build files like production code: typed,
single-sourced, modular. When a rule is unclear, see
`platforms/android/docs/android-gradle-details.md`.

## Version catalog -- single source of truth

- ALL versions, libraries, and plugins live in
  `gradle/libs.versions.toml`. No version literals anywhere
  else in the build.
- Module build scripts reference dependencies as
  `implementation(libs.kotlinx.coroutines)`, never as a
  hard-coded `"org.jetbrains.kotlinx:kotlinx-coroutines:1.x.y"`.
- Catalog organizes into three sections: `[versions]` (bare
  numbers), `[libraries]` (group:artifact + version ref),
  `[plugins]` (plugin id + version ref).

## Kotlin DSL only

- ALL build scripts MUST be `.kts` (Kotlin DSL). No Groovy
  `.gradle` files for new modules.
- Kotlin DSL gives IDE completion, refactor support, and type
  checking on the build graph. Groovy gives none of those.

## Convention plugins for shared module config

- A `buildLogic/` (or `build-logic/`) directory contains an
  included build that hosts custom Gradle plugins.
- Each module-shape (Android app, Android library, Kotlin
  library, Hilt feature) gets a convention plugin
  (`com.example.android.application`, `com.example.android.library`,
  etc.) that applies the right set of plugins and standard
  configuration.
- A module's `build.gradle.kts` reduces to "apply this
  convention + declare these dependencies." Compile options,
  Java version, Kotlin compiler args -- all in the convention.

## No `allprojects { }` / `subprojects { }` in root

- The root `build.gradle.kts` should NOT loop over
  `allprojects` or `subprojects` applying plugins. That hides
  module behavior in a global file no one reads.
- Push module behavior into convention plugins instead. A reader
  of `featureX/build.gradle.kts` learns everything by reading
  that file plus its applied conventions.

## Java / Kotlin version

- `compileOptions { sourceCompatibility = JavaVersion.VERSION_21 ; targetCompatibility = JavaVersion.VERSION_21 }`
  in the Android convention plugin.
- `kotlinOptions { jvmTarget = "21" }` (or the new
  `compilerOptions.jvmTarget` DSL).
- Pinning a single Java version across modules avoids the
  ClassCastException class of bugs that happen when one module
  compiles to 17 and another to 21.

## R8 for release

- Release build types MUST set `isMinifyEnabled = true` and
  `isShrinkResources = true`. R8 ships, ProGuard does not.
- Keep rules in `proguard-rules.pro` per module; the library
  variant uses `consumerProguardFiles("consumer-rules.pro")`
  to ship rules to consumers.
- Debug builds skip minification for fast iteration; keep them
  unminified.

## Why this discipline matters

A version catalog kills "upgrade compose in two places, miss
the third" bugs. Convention plugins kill copy-paste in module
scripts. R8 is the only shrinker that gets shipped with Android
tooling -- skipping it doubles the apk and exposes obfuscation
gaps. The rules above keep the build readable a year from now.
