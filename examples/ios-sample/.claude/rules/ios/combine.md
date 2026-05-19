---
description: Combine -- legacy-bridge only, lifetime-scoped cancellables, retain-cycle hygiene.
paths: "**/*.swift"
---

# Combine

Combine predates Swift Concurrency. In new code, prefer
`async/await` + `AsyncSequence`. Combine remains acceptable only
where the surrounding code already uses it, or where a framework
hands you publishers and bridging them away is impractical. When
a rule is unclear, see `platforms/ios/docs/combine-details.md`.

## When to reach for Combine

- The surrounding module is already Combine-shaped, and the new
  code would be the only async/await island.
- A framework you do not own returns a `Publisher` you cannot
  bridge cleanly (some Apple APIs still do).
- You need behavior that AsyncSequence does not cleanly express
  (multicasting, `combineLatest` across N inputs).

In every other case, AsyncSequence + `Task` is the right answer.

## When NOT to reach for Combine

- New code with no existing Combine surface.
- ViewModels with state -- use `@Published` + `async/await`, or
  `@Observable` on iOS 17+. Do not pipe ten operators to update
  one `@Published` property.
- Anywhere you can write a `for await ...` loop instead.

## Lifetime -- `Set<AnyCancellable>` scoped to the owner

- Every Combine subscription returns an `AnyCancellable`. Store
  it in a `private var cancellables: Set<AnyCancellable> = []`
  tied to the OWNING object's lifetime.
- The owner's `deinit` (implicit, when the set is released)
  cancels all subscriptions. NEVER store an `AnyCancellable` in
  a static or global -- the subscription will outlive its
  intended scope.

## Subjects -- pick the right one

- `CurrentValueSubject<Output, Failure>` -- has a current value
  a new subscriber receives immediately. Use for state-like
  behavior (e.g., "current user", "active theme").
- `PassthroughSubject<Output, Failure>` -- has no current value.
  Use for events ("button tapped", "logout requested").
- `@Published` -- a `CurrentValueSubject` glued to a property
  on an `ObservableObject`. Use inside ViewModels for state.

## Retain cycles -- the recurring bug

- `assign(to:on:)` -- the `on:` parameter is captured strongly.
  If `self` is `on:`, you have a retain cycle.
- Closure-based `sink { ... }` captures freely unless you
  declare `[weak self]`. Always declare `[weak self]` (or
  `[unowned self]` if the cycle is impossible for invariant
  reasons).
- `assign(to: &$published)` (the property-wrapper form) is
  safe -- it manages weakness internally. Prefer it.

## Bridging Combine to async/await

- `publisher.values` gives you an `AsyncPublisher`; iterate with
  `for await value in publisher.values { ... }`.
- For a "single value, then complete" publisher, use `await`
  on `publisher.first().values` or write a `try await
  withCheckedThrowingContinuation` shim.
- NEVER bridge async/await back to Combine unless a framework
  forces you. The cost is one extra layer of allocation, plus
  the loss of cancellation propagation.

## Why this discipline matters

Combine subscriptions are easy to forget about. They run until
the cancellable is released; if you stored it in the wrong
place, the work runs forever. Strict ownership +
`Set<AnyCancellable>` tied to lifetime is what keeps the
framework from becoming a leak factory.
