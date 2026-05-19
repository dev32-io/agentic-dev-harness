---
description: Kotlin idioms -- immutability, null safety, coroutines, sealed types.
paths: "**/*.kt,**/*.kts"
---

# Kotlin

Kotlin's type system is a tool for pushing failure modes from
runtime to compile time. The idioms below preserve that property.
When a rule is unclear, see
`platforms/android/docs/kotlin-details.md`.

## Immutability first

- `val` over `var`. Use `var` only when the variable's identity
  must change and the surrounding scope is small.
- `List`, `Map`, `Set` are immutable views by default. Reach for
  `MutableList` etc. only when local mutation is the point.
- `data class` for records of values. Update with `.copy(...)`.

## Null safety -- no `!!`

- `!!` defeats the type system. NEVER use it.
- Prefer `?.` for safe access, `?:` for fallback, smart-cast
  inside `if (x != null)` blocks for narrowed types.
- For invariant violations: `requireNotNull(x) { "msg" }` or
  `checkNotNull(x) { "msg" }`. These throw with a useful message
  instead of `KotlinNullPointerException`.
- For external input: return `T?` from the parser and let the
  caller decide. Don't smuggle nullability past the boundary.

## Coroutines and structured concurrency

- Launch from a scope you own: `viewModelScope`, `lifecycleScope`,
  or a `CoroutineScope` tied to your component's lifecycle.
- NEVER `GlobalScope.launch { ... }`. It leaks the job past the
  caller's lifetime and breaks cancellation propagation.
- `suspend` functions are cancellable at every suspension point;
  cooperate by calling `ensureActive()` in long CPU loops.
- Pick the dispatcher at the boundary, not deep in the call tree:
  `withContext(Dispatchers.IO) { ... }` wraps blocking I/O,
  `Dispatchers.Default` for CPU work, `Main` for UI mutation.

## Sealed types for closed sums

- `sealed class` / `sealed interface` for "one of a fixed set".
  The compiler enforces exhaustive `when` -- adding a new variant
  forces every consumer to handle it.
- Prefer sealed types over `enum class` when variants carry
  different data shapes. Use `enum class` for plain tags.
- Use sealed types for UI state, results, intents -- anywhere a
  consumer needs to discriminate.

## Extension functions

- Extension functions add behavior at a call site without
  inheritance. Use them for additive helpers that read naturally.
- An extension MUST NOT hide mutable state -- it has no `this`
  field, only a receiver. If you want state, use a class.
- Keep extensions in a small, topical file (`StringExtensions.kt`)
  rather than scattering them across the codebase.

## Result at boundaries

- A function that can fail in a known, expected way returns
  `kotlin.Result<T>` or a domain sealed class (`sealed class
  LoadOutcome { data class Ok(...) : LoadOutcome(); data class
  Err(...) : LoadOutcome() }`).
- Throw for bugs (invariant violations, programmer errors).
  Return `Result` / sealed-class for expected failures (network
  down, parse failure, not found).
- Public boundary signatures MUST declare the failure shape. A
  caller reading the type alone should know what can go wrong.

## Why this discipline matters

A long-running agent reads types as load-bearing documentation.
`!!` and uncaught throws erase that documentation. Immutability
and sealed types let the next agent reason about a function from
its signature alone -- no need to read the body to learn what
states it can produce or what failures it can emit.
