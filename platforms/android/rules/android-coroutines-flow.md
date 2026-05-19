---
description: Coroutines and Flow -- StateFlow/SharedFlow, lifecycle-aware collection, dispatcher discipline.
paths: "**/*.kt,**/*.kts"
---

# Coroutines and Flow

Flow is Kotlin's cold-stream primitive; `StateFlow` and
`SharedFlow` are hot variants for state and events. The
discipline below keeps collection cost bounded and cancellation
honored. When a rule is unclear, see
`platforms/android/docs/android-coroutines-flow-details.md`.

## Cold vs hot

- `Flow<T>` -- cold. The producer block runs once per collector,
  on demand. Use for "compute and emit when asked."
- `StateFlow<T>` -- hot, holds exactly one current value, replays
  it to new collectors. Use for UI state.
- `SharedFlow<T>` -- hot, configurable replay/buffer, no "current
  value." Use for one-shot events (Effects, navigation).

## Lifecycle-aware collection

- In Compose: `flow.collectAsStateWithLifecycle()` -- pauses
  collection when the screen is below STARTED, resumes on
  STARTED. Cheaper than the lifecycle-unaware variant.
- In Fragment/Activity: collect inside
  `lifecycleScope.launch { repeatOnLifecycle(STARTED) { flow.collect { ... } } }`.
- NEVER collect on `GlobalScope` or with a manually constructed
  `CoroutineScope` whose lifetime is unclear -- the collector
  outlives its consumer and leaks.

## Dispatchers

- `Dispatchers.IO` -- blocking I/O (file, network, database).
  Sized for many waiting threads.
- `Dispatchers.Default` -- CPU-bound work (parsing, sorting,
  compression). Sized roughly to core count.
- `Dispatchers.Main.immediate` -- UI mutation. `immediate` skips
  the dispatch when already on the main thread.
- Pick the dispatcher at the boundary, not inside the hot path.
  A repository function uses `withContext(Dispatchers.IO)`
  around the blocking call; the ViewModel doesn't care.

## Cancellation cooperation

- Every `suspend` function is a cancellation point. The body
  yields cooperatively when the surrounding job is cancelled.
- For long CPU loops with no suspension call inside, insert
  `ensureActive()` periodically; otherwise the loop ignores
  cancellation.
- NEVER catch `CancellationException` and swallow it. Either
  let it propagate, or rethrow after cleanup.

## Backpressure operators

- `buffer(capacity)` -- decouples producer/consumer with a
  bounded queue.
- `conflate()` -- "drop intermediate emissions" when the
  consumer can't keep up. Use for UI state that doesn't need
  every intermediate value.
- `sample(period)` / `debounce(period)` -- time-based emission
  filters. Use for search-as-you-type, scroll position.

## Joining streams

- `combine(a, b) { x, y -> ... }` -- emits whenever either
  source emits, using the latest from each.
- `zip(a, b) { x, y -> ... }` -- emits only when both produce a
  new value (strict pairing). Rare in practice.
- `flatMapLatest { upstreamItem -> downstreamFlow(upstreamItem) }` --
  "when a new upstream item arrives, cancel the in-flight
  downstream and start fresh." The search-as-you-type idiom.

## Why this discipline matters

Flow is the right abstraction for "values over time," but it's
easy to write a flow that leaks (no lifecycle), wastes work (no
dispatcher discipline), or hides bugs (silently dropped values).
The rules above force the agent to choose the variant and the
operator explicitly, so the cost and lifetime of every stream
are visible at the call site.
