# Mobile Rules + Examples Audit — Android / iOS

**Date:** 2026-05-19
**Scope:** `platforms/android/`, `platforms/ios/`, `platforms/mobile/`, `examples/android-sample/`, `examples/ios-sample/`.
**Bar:** correctness + currency vs Google AOSP / Apple guidance as of May 2026. Extra weight on Android (staff-Android interview prep).
**Verdict:** Rules are well-structured and opinionated, but Android side has multiple **hard correctness bugs** (example will not build with the toolchain the rules claim), several **stale-doc** patterns (Effect via SharedFlow, stability annotations under strong-skipping), and **staff-level gaps** (Baseline Profiles, modularization, adaptive layouts, foreground service types, KSP). iOS side is broadly current but trails Swift 6 / Observation defaults.

The numbering uses A-/I-/M-/G- prefixes (Android, iOS, Mobile-overlay, staff-Gap). Each finding has: **What**, **Why it’s wrong**, **Evidence**, **Fix**.

---

## P0 — Android-sample is broken under the toolchain it claims

### A1. Kotlin 2.0 + Compose without the Compose Compiler Gradle plugin

**What.** `examples/android-sample/app/build.gradle.kts` declares Kotlin 2.0.0 *and* still sets `composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }`.

**Why it’s wrong.** With Kotlin 2.0+, the Compose compiler is no longer the standalone artifact configured by `kotlinCompilerExtensionVersion`. It must be applied as a Gradle plugin: `org.jetbrains.kotlin.plugin.compose`, version-matched to Kotlin. The legacy block is ignored / errors depending on AGP version. AOSP migration guide is explicit on this.

**Evidence.** `examples/android-sample/app/build.gradle.kts:13-22`; `gradle/libs.versions.toml` (no `compose` plugin entry); rule `platforms/android/rules/android-compose.md` (silent on Compose plugin); rule `platforms/android/rules/android-gradle.md` (silent on Compose plugin).

**Fix.**
- Add to `gradle/libs.versions.toml [plugins]`: `compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }`.
- Add `alias(libs.plugins.compose.compiler)` to `app/build.gradle.kts`.
- Delete the `composeOptions { kotlinCompilerExtensionVersion = ... }` block.
- Update `platforms/android/rules/android-compose.md` to mandate the plugin and the matching catalog entry. Update `android-compose-details.md` with the new snippet.

---

### A2. Java 17 vs Java 21 — rule and sample disagree

**What.** `android-gradle.md:56-59` mandates `JavaVersion.VERSION_21` + `jvmTarget = "21"`. Sample uses `VERSION_17` + `jvmTarget = "17"`.

**Why it’s wrong.** Direct contradiction. Mixed versions across modules is the exact bug the rule warns about (`ClassCastException` class).

**Fix.** Pick one (Java 21 is fine for AGP 9.x). Align sample to rule, or relax rule. Recommend Java 21 + Kotlin `compilerOptions.jvmTarget = JvmTarget.JVM_21` DSL.

---

### A3. Toolchain pins are 1–2 years stale; sample will be rejected by Play

**What.** Catalog pins: AGP 8.5.0, Kotlin 2.0.0, Compose BOM 2024.06.00, Hilt 2.51, activity-compose 1.9.0, compileSdk/targetSdk 34, minSdk 24.

**Why it’s wrong (May 2026 reality).**
- **AGP** stable is 9.2.0 (April 2026) — supports Android API 37, requires Gradle 8.11+.
- **Kotlin** 2.1.x is GA; 2.0.0 has known Compose stability inference bugs.
- **Compose BOM** stable is 2026.05.00 (Compose 1.11.1).
- **Hilt** stable is 2.56 with KSP support since 2.48.
- **compileSdk/targetSdk 34** — Play Store rejects new app submissions and updates targeting API < 35 since Aug 31 2025. **API 36 is required** for new submissions/updates after May 31 2026 alongside the 16 KB page alignment requirement. The sample as shipped today would be **rejected**.

**Fix.** Update catalog:
```toml
[versions]
agp = "9.2.0"
kotlin = "2.1.20"
compose-bom = "2026.05.00"
activity-compose = "1.10.1"   # check current
hilt = "2.56"
ksp = "2.1.20-1.0.31"          # matches Kotlin
lifecycle = "2.10.0"
navigation = "2.10.0"          # 2.8+ has type-safe routes
hilt-navigation-compose = "1.3.0"
kotlinx-serialization = "1.7.3"
```
- Bump `compileSdk` and `targetSdk` to **36**; `minSdk` stays 24 unless project says otherwise.
- Add the wrapper (`gradle wrapper --gradle-version 8.11`) so `./gradlew` is in the repo.

---

### A4. App `build.gradle.kts` hard-codes versions — directly violates `android-gradle.md`

**What.** `app/build.gradle.kts:32-37` uses `implementation("androidx.activity:activity-compose:1.9.0")` and `platform("androidx.compose:compose-bom:2024.06.00")` — string literals, not catalog refs. The version catalog exists with these entries but is unused.

**Why it’s wrong.** Rule `android-gradle.md:13-23` says "ALL versions, libraries, and plugins live in `gradle/libs.versions.toml`. No version literals anywhere else." The sample is the live counter-example to its own rule.

**Fix.** Switch every dep to `libs.*`:
```kotlin
implementation(platform(libs.compose.bom))
implementation(libs.compose.material3)
implementation(libs.activity.compose)
implementation(libs.lifecycle.runtime.compose)   // see A6
```

---

### A5. MainActivity does not call `enableEdgeToEdge()` and uses a Material1 theme

**What.** `MainActivity.kt` calls `setContent { MaterialTheme { ... } }` with no `enableEdgeToEdge()`. `AndroidManifest.xml` declares `android:theme="@android:style/Theme.Material.Light.NoActionBar"`.

**Why it’s wrong.**
- Once `targetSdk = 35` (the moment the sample is fixed for A3), edge-to-edge is the **enforced default**. The activity must call `enableEdgeToEdge()` (from `androidx.activity`) before `setContent` to set up insets correctly; without it, content sits under the status/nav bars.
- `Theme.Material.Light.NoActionBar` is the *framework* Material1 theme. Compose Material3 expects an AppCompat/Material3-compatible base (typically `Theme.Material3.DayNight.NoActionBar` from `com.google.android.material:material`, or a project-defined Theme that inherits from it). Mixing M1 theme XML with M3 composables silently breaks insets, status-bar contrast, dynamic color, and predictive-back affordances.

**Fix.**
```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()
    setContent { AppTheme { Surface { /* ... */ } } }
}
```
- Add `com.google.android.material:material` dep and declare a `Theme.AppName` in `res/values/themes.xml` inheriting `Theme.Material3.DayNight.NoActionBar`.

---

### A6. Rules / details use `collectAsStateWithLifecycle` but no dependency declares it

**What.** Rules `android-compose.md`, `android-coroutines-flow.md`, and the MVI details file all use `collectAsStateWithLifecycle()`. It lives in `androidx.lifecycle:lifecycle-runtime-compose:2.8.0+` (now 2.10.0). Not in catalog, not in app deps.

**Why it’s wrong.** Anyone applying the rule verbatim hits an unresolved reference.

**Fix.** Add `lifecycle-runtime-compose` to catalog + app, reference from the rule. Update sample to compile a minimal `collectAsStateWithLifecycle` example so future readers see the import path.

---

### A7. Hilt rule prescribes `hiltViewModel()` but never tells you which artifact

**What.** `android-hilt-di.md:22-23` says use `hiltViewModel()` from `androidx.hilt:hilt-navigation-compose`. The catalog does not declare it, nor does it declare the Hilt KSP compiler (`androidx.hilt:hilt-compiler` or `dagger.hilt.android.plugin`).

**Fix.** Catalog adds:
```toml
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version.ref = "hilt-navigation-compose" }
```
App declares Hilt + KSP plugin (see A8).

---

## P1 — Rule correctness (currency / wrong-doc)

### A8. Hilt rule never says "use KSP, not KAPT"

**What.** `android-hilt-di.md` is silent on annotation processor. The Hilt 2.48 release notes (2023) added KSP support; 2.5x is now the default story. KAPT is on the JetBrains deprecation path.

**Why it matters at staff bar.** KSP is roughly 2× the speed of KAPT on incremental builds. A staff Android engineer is expected to default-choose KSP and migrate legacy KAPT.

**Fix.** Add a "Use KSP for annotation processing" section to `android-hilt-di.md`. Update Hilt module example to use `ksp(libs.hilt.compiler)` not `kapt(...)`. Add KSP plugin to catalog (id `com.google.devtools.ksp`).

---

### A9. `Effect` via `SharedFlow(replay=0, extraBufferCapacity=1)` is the deprecated event pattern

**What.** `android-architecture-mvi.md:31-32` and the MVI details file (`android-architecture-mvi-details.md:76-94`) model one-shot events as a `MutableSharedFlow` with `replay=0, extraBufferCapacity=1`. Composables collect this in a `LaunchedEffect`.

**Why it’s wrong.** This is the **lossy** pattern Google’s own architecture guidance has been steering away from since ~2022. With `collectAsStateWithLifecycle` semantics (collection pauses below STARTED), a `SharedFlow.emit` issued while the screen is paused will be **dropped** if the buffer is already drained — exactly the class of bug the rule claims to prevent. Current Google "Now in Android" guidance: model events **inside `UiState`** with a "consumed" boolean / one-shot reducer; alternatively use `Channel<Effect>` → `receiveAsFlow()` (Channel guarantees delivery; multiple collectors are disallowed which matches the single-screen contract).

**Fix.** Rewrite the rule to recommend **one of two** patterns, both correctness-preserving:
1. **Events-in-state (preferred).** `UiState.toast: Toast? = null`; reducer sets it; composable calls `viewModel.dispatch(Consumed.Toast)` after showing it.
2. **`Channel<Effect>` consumed as `receiveAsFlow()`** with single collector.
Delete the SharedFlow pattern from the details file, replace with both. Cite the actual reason (lifecycle-paused collection dropping events).

---

### A10. Compose rule’s stability advice predates strong-skipping

**What.** `android-compose.md:57-66` instructs marking types `@Immutable` / `@Stable` to keep composables skippable.

**Why it’s incomplete.** Strong-skipping mode is **on by default in Compose Compiler 2.0+**. With strong-skipping, all restartable composables are skippable regardless of param stability; the runtime falls back to referential-equality on unstable types. `@Stable`/`@Immutable` still matter for `List<T>` parameters with cheap structural equality and for cross-module types whose stability isn’t inferred — but the framing in the rule (annotate-or-recompose) is obsolete.

**Fix.** Rewrite the stability section: explain strong-skipping is the default, explain when `@Stable`/`@Immutable` *do* still pay off (cross-module types, expensive `equals()`, lambdas-with-captured-state). Add a pointer to compose-compiler reports (`metricsDestination` / `reportsDestination`) for actually measuring skippability.

---

### A11. No Android navigation rule despite mobile-navigation principles

**What.** `platforms/mobile/rules/mobile-navigation.md` lays out typed-routes-as-sum-types as a principle. No `platforms/android/rules/android-navigation.md` exists to make it concrete.

**Why it matters.** Navigation 2.8+ ships **type-safe routes** built on `kotlinx.serialization`: `@Serializable object Home`, `@Serializable data class Profile(val id: String)`, `composable<Profile> { ... }`. This is the production pattern for 2026 and matches the mobile rule’s "typed not stringly" mandate exactly. Without an Android-specific rule pointing to it, an agent will reach for the old string-route APIs.

**Fix.** Add `platforms/android/rules/android-navigation.md`:
- Mandate Navigation 2.8+ + `kotlinx.serialization`.
- `@Serializable` route classes; `composable<Route> { backStackEntry -> backStackEntry.toRoute<Route>() }`.
- Single-activity, `NavHost` per nav graph.
- Bottom-tab roots as nested graphs (matches `mobile-navigation.md:48-54`).
- Deep links via `@Serializable` + `deepLinks = listOf(navDeepLink<Route>(...))`.
- Test: navigation actions as effects; assert via `navController.currentBackStackEntry?.toRoute()`.

Catalog additions:
```toml
navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation" }
kotlinx-serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version = "1.7.3" }
```
Plugin: `kotlin-serialization`.

---

### A12. Gradle rule mandates R8 but says nothing about Baseline Profiles

**What.** `android-gradle.md:65-72` covers R8 / shrinkResources, then stops. Baseline Profiles (`androidx.baselineprofile` gradle plugin + `androidx.benchmark:benchmark-macro-junit4`) are unmentioned.

**Why it matters.** Cold-start latency budget (`platforms/android/qa/oracles.md` claims <2s) is unreachable on mid-tier devices without baseline profiles. Staff Android candidates are expected to know how to author + generate + verify a baseline profile and gate regressions in CI.

**Fix.** Add `platforms/android/rules/android-performance.md`:
- Baseline profile module skeleton (`:benchmark`).
- `BaselineProfileRule` + `MacrobenchmarkRule` patterns.
- `androidx.metrics.performance:JankStats` registration in Activity / `JankStatsAggregator`.
- StartupTracker / `androidx.startup:startup-runtime` for initializers.
- Compose-specific: `composable_skippable` reports, `LaunchedEffect` reads, `LazyColumn` key stability.

---

### A13. Testing rule misses Robolectric + JVM screenshot tests

**What.** `android-testing.md` Layer 1 (JVM unit) → Layer 2 (Compose UI under `androidTest`/`HiltTestActivity`) → Layer 3 (instrumented) → Layer 4 (Maestro).

**Why it’s incomplete.** Two big mid-pyramid layers are missing:
- **Robolectric** for "Android-shaped tests on the JVM" (resource resolution, AndroidX Lifecycle plumbing). Pairs with Compose UI tests since `createComposeRule()` actually needs an Android lifecycle host — Robolectric + Roboelectric `ApplicationProvider` is the JVM-native path that avoids a real emulator.
- **Paparazzi (Cash App)** / **Roborazzi** for screenshot regression on JVM. These are now standard in Compose pipelines and have replaced "let’s eyeball previews."

**Fix.** Add Layer 1.5: "JVM with Android facades — Robolectric + Roborazzi" with rationale + a worked snippet. The quality-gate-android.sh script should grow a `screenshot` target.

---

## P2 — Mobile-overlay gaps

### M1. `mobile-lifecycle.md` predates Android 16 background-budget specifics

**What.** Rule says "single-digit seconds" for flush-on-background. Doesn’t name `ApplicationExitInfo`, `ForegroundServiceType`, or the Android 14+ requirement to declare `foregroundServiceType` (`dataSync`, `mediaPlayback`, etc.) in the manifest *and* at start time. Android 15 narrowed the allowed types further. Android 16 enforces stricter background-start restrictions.

**Fix.** Add a "Foreground services on modern Android" section linking out to a new `platforms/android/rules/android-foreground-services.md`. Reference `ApplicationExitInfo` for post-mortem analysis of process death.

### M2. `mobile-offline.md` is principle-only, never names the platform building blocks

**What.** Says "persistent local store" without naming Room (Android) or SwiftData/Core Data (iOS). Says "background syncer" without naming WorkManager (Android) or BGTaskScheduler (iOS).

**Why this is debatable.** Mobile overlay is intentionally cross-platform. But a reader gets no traceability into "what concrete API satisfies this." Currently the only landing place would be an Android docs file that doesn’t exist.

**Fix.** Either keep mobile overlay abstract and add `android-data-storage.md` + `ios-data-storage.md` rules, **or** add a "Platform mapping" block at the bottom of each mobile rule.

### M3. iOS chain pulls `mobile` but mobile rules lack `paths:` globs

**What.** `platforms/android/rules/*.md` declare `paths: "**/*.kt,**/*.kts"`. `platforms/mobile/rules/*.md` declare no `paths:` at all (see frontmatter of each file).

**Why this matters.** Per `CLAUDE.md.template:9-10`, rules in subdirectories auto-load **only** when their `paths:` glob matches a touched file. A rule with no `paths:` either never auto-loads or loads always — depends on Claude Code semantics; either way it’s implicit and inconsistent with the Android subset.

**Fix.** Decide on intent. If mobile rules should auto-load on any mobile-platform file, add `paths: "**/*.kt,**/*.kts,**/*.swift"`. Document this convention in `CLAUDE.md.template`.

---

## P3 — iOS

### I1. ios-sample test file is named `ContentViewModelTests` but tests nothing ViewModel-related

**What.** `Tests/ContentViewModelTests.swift` contains `XCTAssertEqual(2 + 2, 4)`.

**Why it matters.** Sample is the literal demonstration of "what landing the harness looks like." It should demonstrate a tiny `@Observable` ViewModel + a `@MainActor` test verifying `state` after a method call. As written it teaches nothing and matches none of the rules in `swiftui.md` / `ios-architecture-mvvm.md`.

**Fix.** Replace ContentView with a minimal `@Observable` `CounterViewModel` (state + `increment()`); write one Swift Testing `@Test` asserting state transitions on the `@MainActor`. Demonstrate `#Preview` with injected fake.

### I2. Swift 6 strict concurrency unmentioned

**What.** `swift-concurrency.md` says "enable strict concurrency checking" without naming the build setting (`SWIFT_STRICT_CONCURRENCY = complete`) or that Swift 6.0 (Sept 2024) made strict concurrency the language default. iOS rules should treat Swift 6 strict mode as the baseline.

**Fix.** Add a "Swift 6 mode" section: `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete` in `.xcconfig`. Explain `Sendable` upgrades, isolated conformances, region-based isolation.

### I3. SwiftUI rule still leads with `@StateObject` / `@ObservedObject`

**What.** `swiftui.md:24-35` enumerates `@State` / `@StateObject` / `@ObservedObject` / `@Environment` and then notes iOS 17+ Observation as a one-line caveat.

**Why it’s wrong for new code.** iOS 17 was 2.5 years ago in May 2026. New code targeting iOS 17+ should *default* to `@Observable` + plain `@State`/`@Bindable`. The rule’s ordering implies the old wrappers are primary; that’s no longer true.

**Fix.** Reorder: lead with `@Observable` + `@State`/`@Bindable`; treat `@StateObject`/`@ObservedObject` as the legacy path. Mention `@Environment` is still the right ambient-deps story.

### I4. iOS sample uses XCTest while the rule names Swift Testing as preferred

**What.** Rule `ios-testing.md:14-18` says Swift Testing for new code on iOS 17+/Xcode 16+. Sample uses XCTest.

**Fix.** Migrate `Tests/ContentViewModelTests.swift` to Swift Testing (`@Test func smoke() { #expect(2 + 2 == 4) }`).

### I5. ios-sample `quality-gate.sh` invocation is broken (self-acknowledged)

**What.** `examples/ios-sample/README.md` literally says: *"the bundled `quality-gate.sh` invokes `xcodebuild` without `-scheme`/`-destination`."*

**Fix.** Either fix `scripts/quality-gate.sh` to dispatch to `platforms/ios/hooks/quality-gate-ios.sh` (which presumably does have those flags), or in-line the correct invocation. Auto-detect the scheme from the single `App.xcodeproj`.

---

## Staff-level Android gaps (not bugs — but expected at the bar)

Rules that don’t exist and should:

| ID | Proposed rule file | Topic |
|----|---|---|
| G1 | `android-modularization.md` | `:app`, `:feature:*`, `:core:data`, `:core:ui`, `:core:designsystem` per Now in Android; convention plugins per module shape (the existing `android-gradle.md` mentions convention plugins but no module shape catalog). |
| G2 | `android-performance.md` | Baseline Profiles, Macrobenchmark, JankStats, frame timing, startup tracking, Compose recomposition reports. |
| G3 | `android-adaptive.md` | Window size classes (`androidx.window`), `material3-adaptive-navigation-suite`, list-detail and supporting-pane scaffolds, foldable posture, Compose `BoxWithConstraints` vs window classes. |
| G4 | `android-foreground-services.md` | `foregroundServiceType` declarations, runtime permissions for FGS types, exact-alarm permission, user-initiated data transfer FGS. |
| G5 | `android-data-storage.md` | Room (+ `@AutoMigration`), DataStore (Preferences + Proto), `EncryptedSharedPreferences` deprecation → `androidx.security:security-crypto` replacement, file-system `Context.filesDir` vs scoped storage. |
| G6 | `android-background-work.md` | WorkManager (`expedited`, `chained`, `unique`), constraints; `JobScheduler` is the wrong default. |
| G7 | `android-navigation.md` | See A11 — type-safe routes (Nav 2.8+ + serialization). |
| G8 | `android-permissions.md` | Permission rationale flow, `ActivityResultContracts.RequestPermission`, notification permission on Android 13+, package visibility queries. |
| G9 | `android-resources.md` | Resource quality discipline, `android:label` / app name via `<string>` not literal, density-independent assets, dynamic color (`monet`). |

Static analysis the harness ships should grow: Detekt + Ktlint integration in the quality-gate hook. The existing `quality-gate-android.sh` runs lint / assemble / test — that’s the AOSP `lint` only, not the Kotlin-quality layer staff candidates are expected to wire up.

---

## Fix plan (suggested execution order)

**Phase 1 — Make the example actually build (P0).**
1. Update `gradle/libs.versions.toml` to current pins (A3).
2. Apply Compose Compiler plugin (A1) + serialization plugin (A11 prereq).
3. Reconcile Java version (A2).
4. Switch every dep to catalog refs (A4).
5. Add missing libraries: `lifecycle-runtime-compose`, `hilt-navigation-compose`, `navigation-compose`, `kotlinx-serialization-json` (A6, A7, A11).
6. Add `enableEdgeToEdge()` + Material3-compatible theme + `com.google.android.material:material` (A5).
7. Commit `gradle wrapper` + verify `./gradlew assembleDebug` locally.

**Phase 2 — Rule corrections (P1).**
8. Rewrite Effect pattern (A9): events-in-state primary; Channel secondary.
9. Rewrite Compose stability section (A10): strong-skipping default + when annotations still pay.
10. Add KSP mandate to Hilt rule (A8).
11. Add `android-navigation.md` (A11).
12. Add testing-rule augment for Robolectric + Roborazzi (A13).
13. Add `android-performance.md` (A12 / G2).

**Phase 3 — Mobile-overlay + iOS (P2 / P3).**
14. Add `paths:` to mobile rules (M3).
15. Add cross-link blocks "platform mapping" (M2).
16. Bump iOS sample to a real `@Observable` ViewModel + Swift Testing (I1, I4).
17. Add Swift 6 strict-concurrency rule additions (I2).
18. Reorder SwiftUI rule to lead with Observation (I3).
19. Fix iOS quality-gate dispatch (I5).

**Phase 4 — Staff-level gap fills (G).**
20. Add G1–G9 rules incrementally, each with paired details file under `platforms/android/docs/`.
21. Wire Detekt + Ktlint into `quality-gate-android.sh`.

---

## What this audit did NOT cover

- The `base/rules/*.md` cross-platform set — only checked enough to confirm they’re imported correctly.
- `install.sh` chain resolution correctness — assumed working per scout reports.
- Actually running `./gradlew assembleDebug` or `xcodebuild build` — both verifications above are static-read findings only. Phase 1 fix-and-verify is recommended before claiming any P0 fix landed.
- The QA charters under `platforms/android/qa/charters/` — content audit deferred.
