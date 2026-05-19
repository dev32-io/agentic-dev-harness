---
description: SwiftUI -- pure views, state hoisting, previews mandatory.
paths: "**/*.swift"
---

# SwiftUI

SwiftUI evaluates view `body` properties many times per second.
A view that lies about its purity recomposes badly, leaks state,
or skips frames. Every rule below protects view-update
correctness. When a rule is unclear, see
`platforms/ios/docs/swiftui-details.md`.

## Pure views

- A view's `body` MUST NOT have side effects. No network calls,
  no file I/O, no mutation of shared state, no analytics fires.
- Side effects belong in `.task { ... }`, `.onAppear { ... }`,
  or `.onChange(of:) { ... }`. SwiftUI decides when to run them.
- `print` for debugging is acceptable. Anything observable to
  the user or to another component is not.

## State property wrappers -- pick the right one

- `@State` -- value-type state owned by this view, local to its
  lifecycle. Resets when the view is removed from the hierarchy.
- `@StateObject` -- reference-type state OWNED by this view. The
  view creates it; SwiftUI keeps it alive across recompositions.
  Use exactly once per object, at the owning level.
- `@ObservedObject` -- reference-type state PASSED IN from a
  parent. The parent owns lifetime; this view just reads it.
- `@Environment(\.dependency)` -- ambient injected dependencies
  (theme, dismiss action, dependency-injected services).
- iOS 17+: `@Observable` macro + plain `let` / `@Bindable`
  replaces most `@StateObject` / `@ObservedObject` usage.

## State hoisting

- Hoist state up. Stateless views are trivial to preview, easy
  to test, and impossible to put into an invalid state.
- A reusable view takes `state: T` and callbacks (`onTap: () -> Void`).
  It MUST NOT reference a ViewModel directly.
- Screen-level views read the ViewModel; leaf views do not.

## Effects -- pick the right modifier

- `.task { ... }` -- async work scoped to the view's lifecycle.
  Cancels when the view leaves the hierarchy. Use for "load
  data when this screen appears."
- `.task(id:) { ... }` -- restarts when the id changes. Use for
  "reload when this input changes."
- `.onChange(of: value) { ... }` -- state-driven side effects.
  Runs when `value` changes, on the main actor.
- `.onAppear` / `.onDisappear` -- non-async lifecycle hooks.
  Prefer `.task` over `.onAppear { Task { ... } }`.

## Previews are mandatory

- Every screen-level view MUST have at least one `#Preview`.
  Multi-state screens get one preview per meaningful state
  (loading, error, populated, empty).
- Previews take fake data; they MUST NOT depend on a real
  network or a real `@StateObject` that does I/O.
- Use multiple preview variants: light/dark
  (`.preferredColorScheme(.dark)`), accessibility sizes
  (`.dynamicTypeSize(.accessibility3)`), and error states.

## Identifiability

- `ForEach` content MUST be `Identifiable` or have an explicit
  `id:` parameter. Anonymous indexing produces wrong animations
  when the collection mutates.
- Use `.id(value)` when you intentionally want the view's
  identity to change as `value` changes (forces a full rebuild).
  Use sparingly -- it disables structural-diff optimizations.

## Why this discipline matters

The SwiftUI runtime relies on purity, state ownership, and
identity to skip work. A side effect in `body` or a wrong
state-wrapper choice silently turns a 60fps screen into a
30fps one with no error to point at. The rules above keep
the framework's optimizations on your side.
