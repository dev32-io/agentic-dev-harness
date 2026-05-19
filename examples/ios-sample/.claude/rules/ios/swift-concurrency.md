---
description: Swift Concurrency -- async/await, structured tasks, Sendable, @MainActor.
paths: "**/*.swift"
---

# Swift Concurrency

Swift Concurrency replaces completion handlers and ad-hoc
threading with structured async/await + actors. The rules below
keep the structure intact -- structured concurrency only buys
you safety if you don't routinely break it. When a rule is
unclear, see `platforms/ios/docs/swift-concurrency-details.md`.

## `async`/`await` over completion handlers

- New code uses `async` functions. NEVER add a new
  `completion: @escaping (Result<T, Error>) -> Void` API to
  internal code.
- Bridge legacy APIs with `withCheckedThrowingContinuation` or
  `withCheckedContinuation` at the boundary. Wrap once; never
  scatter completion handlers above the bridge.

## Tasks -- structured by default

- `Task { ... }` from sync context to start async work. It
  inherits the surrounding actor + priority context.
- `Task.detached { ... }` -- ONLY when you genuinely need to
  drop the parent's actor / priority. The default is wrong far
  more often than detached is right.
- Child tasks via `async let` or `withTaskGroup`. They cancel
  automatically when the parent task cancels.
- Do NOT store `Task` references long-term unless cancellation
  is the explicit requirement. A retained Task that outlives
  its purpose is a memory and effect leak.

## Cancellation cooperation

- `try Task.checkCancellation()` in long loops. Most `async`
  framework calls (URLSession, FileHandle async I/O) already
  cooperate.
- Cancellation is a request, not a guarantee -- write your loops
  to check, then exit cleanly.
- When you store a Task for cancellation, cancel + nil it in
  `deinit` (or in the relevant lifecycle hook).

## AsyncSequence for streams

- For an unbounded stream of values, expose `AsyncStream<T>` or
  `AsyncThrowingStream<T, Error>`. Callers consume via `for await`.
- Prefer `AsyncStream` over Combine publishers in new code.
  AsyncSequence integrates with structured concurrency;
  Combine does not.

## `Sendable` discipline

- Types crossing actor boundaries MUST be `Sendable`. The
  compiler enforces this under strict concurrency checking;
  enable it.
- Value types of `Sendable` parts are `Sendable` for free.
- Reference types need `final class ... : Sendable` (immutable
  state) or `@unchecked Sendable` (you have a real argument for
  why mutation is safe).
- Closures crossing actor boundaries need `@Sendable`.

## `@MainActor` for UI-touching code

- UI properties and methods MUST be `@MainActor`. The compiler
  enforces main-thread invariants statically -- no more
  `DispatchQueue.main.async { ... }` sprinkled defensively.
- ViewModels with UI-bound state are typically `@MainActor` at
  the class level. Methods inside auto-inherit.
- Off-main work hops via `await someOtherActor.method()`; back
  to main is implicit when the calling context is `@MainActor`.

## Actors for shared mutable state

- `actor` for any state shared across concurrent contexts. The
  actor serializes access; no locks needed.
- Actor methods are async at the call site; design around that.
- Avoid storing UI types (`UIView`, `UIViewController`,
  SwiftUI views) inside non-`@MainActor` actors.

## Why this discipline matters

Structured concurrency makes the lifetime of async work
visible in the code. The moment you start using
`Task.detached`, unbounded `Task { }` without storage, or
manual locks instead of actors, that visibility evaporates.
The rules above keep the structure intact.
