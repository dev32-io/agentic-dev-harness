---
description: Hilt DI -- constructor injection, scoped modules, test doubles via @TestInstallIn.
paths: "**/*.kt,**/*.kts"
---

# Hilt Dependency Injection

Hilt is the dependency-injection standard for Android. It
generates the wiring; you declare what's available and where.
Do NOT roll a hand-written service locator -- you lose
compile-time graph validation and the test-replacement story.
When a rule is unclear, see
`platforms/android/docs/android-hilt-di-details.md`.

## Application + entry points

- The `Application` subclass MUST be annotated `@HiltAndroidApp`.
  This is the root of the generated component tree.
- Android entry points (Activity, Fragment, Service, BroadcastReceiver
  that wants injection) MUST be annotated `@AndroidEntryPoint`.
- ViewModels use `@HiltViewModel`. Compose retrieves them via
  `hiltViewModel()` from `androidx.hilt:hilt-navigation-compose`.

## Constructor injection over field injection

- Inject via `@Inject constructor(...)` whenever the class is
  yours to modify. The constructor signature documents the
  dependencies.
- Field injection (`@Inject lateinit var foo: Foo`) is reserved
  for Android-managed classes (Activity, Fragment) where the
  framework owns construction.
- A class with `@Inject constructor` and no `@Module` binding
  is wired automatically -- Hilt knows how to build it.

## Modules and bindings

- A `@Module` annotated `@InstallIn(<Component>::class)`
  declares bindings available in that component's scope.
- `SingletonComponent` -- app-wide singletons.
- `ViewModelComponent` -- per-ViewModel lifetime (rare; mostly
  for use-cases tied to a single VM).
- Use `@Binds` for "interface to implementation" mappings (no
  body, compiler-generated). Use `@Provides` when construction
  needs custom logic (parameters, configuration).

## Scopes

- `@Singleton` -- one instance per app process (within
  `SingletonComponent`).
- `@ActivityRetainedScoped` -- one instance per Activity, but
  survives configuration change. Roughly "ViewModel lifetime."
- `@ViewModelScoped` -- one instance per ViewModel; used
  sparingly when a use-case must share state across collaborators
  inside a single VM.
- Unscoped bindings produce a fresh instance per injection point.
  This is the safe default.

## Test doubles via `@TestInstallIn`

- For tests, replace a production module with a test module
  using `@TestInstallIn(components = [...], replaces = [...])`.
- The test module's bindings override production for the test
  graph; the rest of the graph is untouched.
- This is the ONLY supported way to swap a real dependency for
  a fake in Hilt-managed code. Don't try to subclass the VM in
  the test.

## Why this discipline matters

Hilt's value is compile-time graph validation: a missing binding
fails the build, not a runtime crash on a user's device. Field
injection, manual instantiation, and DIY locators all defeat
that property. The rules above keep the graph machine-checkable
and the test-substitution story uniform.
