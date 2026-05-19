---
description: Swift idioms -- value types, no force-unwrap, protocol orientation, Sendable discipline.
paths: "**/*.swift"
---

# Swift

Swift's type system, like Kotlin's, exists to push failure modes
from runtime to compile time. The idioms below preserve that
property. When a rule is unclear, see
`platforms/ios/docs/swift-details.md`.

## Value types over reference types

- `struct` over `class` wherever identity is not load-bearing.
  Value semantics eliminate a whole class of aliasing bugs.
- Reach for `class` only when you need identity, inheritance, or
  Objective-C interop. `final class` if you do reach for one --
  open inheritance is rarely the answer.
- `enum` (especially with associated values) for closed sums.

## Immutability first

- `let` over `var`. Use `var` only when the binding's value must
  change and the surrounding scope is small.
- Prefer non-mutating methods (`map`, `filter`, `reduce`) over
  in-place mutation. The optimizer can collapse them; readers
  cannot collapse hidden mutation.

## Optionals -- never force-unwrap

- `!` defeats the type system. NEVER use it on optionals you did
  not just construct via `try!`-style local invariants.
- Prefer `if let`, `guard let`, and `??` (nil-coalescing) at
  boundaries. They push the unwrap into a branch the reader
  can see.
- For invariant violations: `guard let x = x else { fatalError("msg") }`
  with a real message. The crash will point at the bug, not at
  the `!`.

## Protocol orientation

- Protocols + protocol extensions are the primary unit of reuse.
  Inheritance from a `class` is a last resort.
- Use protocol extensions to provide default implementations;
  callers can override at the conformance site.
- Compose small protocols (`Equatable`, `Hashable`, `Identifiable`,
  `Sendable`) rather than one big "ViewModel" protocol.

## `Result<Success, Failure>` at boundaries

- Where a function can fail in a known, expected way, return
  `Result<Success, Failure: Error>` -- or `throws` -- not both.
- Public boundary signatures MUST declare the failure shape. A
  caller reading the type alone should know what can go wrong.

## `Sendable` discipline

- Types crossing concurrency boundaries must be `Sendable`.
  Value types of `Sendable` parts are `Sendable` for free.
- Mark reference types `@unchecked Sendable` only with a real
  argument for why their internal state is safe to share.
- Enable strict concurrency checking in the build settings; the
  compiler will tell you the rest.

## `@MainActor` for UI-touching code

- UI-touching properties and methods MUST be `@MainActor`. The
  compiler then enforces the main-thread invariant statically.
- ViewModels that expose UI state are typically `@MainActor`-
  scoped at the class level.

## Errors as enums conforming to `Error`

- Define a domain `enum Error: Error, Sendable` per layer. NEVER
  use `NSError` stringly-typed bags in Swift code.
- Associated values carry the diagnostic detail
  (`case network(URLError)`, `case invalidJSON(reason: String)`).
- A `LocalizedError` conformance handles user-facing messages.

## Why this discipline matters

A long-running agent reads types as load-bearing documentation.
`!` and `NSError` erase that documentation. Value types, `Result`,
and `Sendable` let the next agent reason about a function from
its signature alone.
