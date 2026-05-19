---
description: Mobile navigation -- typed routes, state-aware deep links, defined back behavior.
---

# Mobile Navigation

Navigation is where mobile apps accumulate state-management
debt. Stringly-typed routes and undefined back behavior are the
two biggest sources. When a rule is unclear, see
`platforms/mobile/docs/mobile-navigation-details.md`.

## Routes are typed, not stringly-typed paths

- A destination is a value of a closed sum -- an enum (Swift) or
  sealed class (Kotlin) -- with the destination's required
  arguments as associated values / properties.
- The router accepts only that typed value. Raw `String` paths
  cross the boundary only at the URL parser and the URL formatter.
- The compiler then enforces that every destination has the
  arguments it needs. Adding a destination forces every dispatch
  site to acknowledge it.

## Deep links land at the right STATE, not just the right screen

- A deep link does NOT just push a screen. It pre-populates the
  state the user reasonably expects to find: the right tab
  selected, the right item highlighted, the right filter applied.
- Define for each linkable destination: what loads synchronously
  from the URL, what is fetched async, and what the loading-state
  UI looks like while the async work runs.
- The URL is therefore a serialized form of "where the user is."
  Round-tripping (read current state → format URL → re-parse →
  state) MUST equal the original state.

## Every screen has a defined "back" target

- "Back" is not a free variable. For every screen, the spec
  answers: where does back go? The system back gesture, the
  in-screen back button, and the navigation-bar back chevron
  MUST agree.
- After a multi-step flow (e.g. checkout), back from the
  confirmation screen does NOT pop into the middle of the flow.
  The flow is replaced; back returns to the entry surface.
- Modals: dismissing a modal restores the underlying screen as
  it was. Tasks inside a modal do not leak back-stack entries
  into the parent.

## Tabs are roots, not pushable destinations

- A tab is a navigation root with its own back stack. Switching
  tabs does NOT push onto a global stack.
- A deep link into a tabbed app selects the right tab AND drives
  that tab's stack to the destination. The other tabs retain
  their state.

## Forbidden patterns

- Passing a giant object through the route. Pass the ID; refetch
  on the other side. Routes get serialized for restore; large
  payloads break that.
- "Navigate by side effect" -- mutating a global variable and
  then letting the next render notice. Navigation is an explicit
  call; the call site is searchable.
- Conditional `back` behavior that depends on how the user got
  there. If the screen needs to know its caller, that is a flow
  with an explicit entry point, not free-form navigation.

## Why this discipline matters

The agent that reads a stringly-typed `navigator.push("/x/y")`
cannot tell what arguments `/x/y` needs. The agent that reads
`navigator.go(.product(id: pid))` sees the contract in the type.
Typed routes plus defined back behavior turn navigation from
folk knowledge into a property of the code.
