---
description: Hilt DI -- constructor injection, scoped modules, KSP, @TestInstallIn for test doubles.
paths: "**/*.kt,**/*.kts"
---

# Hilt Dependency Injection

Hilt generates the wiring with compile-time graph validation. NEVER hand-roll a service locator.

## Application + entry points

- `Application` → `@HiltAndroidApp`. Activity/Fragment/Service/Receiver → `@AndroidEntryPoint`.
- ViewModels → `@HiltViewModel`. Compose: `hiltViewModel()` from `androidx.hilt:hilt-navigation-compose`.

## Constructor injection — default

- `@Inject constructor(...)` whenever the class is yours. Field injection only for framework-owned types.
- A class with `@Inject constructor` and no binding wires automatically.

## Modules + bindings + scopes

- `@Module @InstallIn(<Component>::class)` scopes bindings. `@Binds` interface→impl; `@Provides` custom construction.
- `@Singleton` one per process; `@ActivityRetainedScoped` survives config change; `@ViewModelScoped` sparingly.
- Unscoped (default) — fresh instance per injection point.

## KSP, not KAPT (A8)

- Apply `com.google.devtools.ksp`; replace `kapt(libs.hilt.compiler)` with `ksp(libs.hilt.compiler)`.

## Test doubles — `@TestInstallIn`

- `@TestInstallIn(components = [...], replaces = [...])` swaps a production module for a test one.
- ONLY supported swap mechanism. Do NOT subclass the VM in tests.

See `platforms/android/docs/android-hilt-di-details.md`.
