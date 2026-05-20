---
description: MVVM -- ObservableObject, navigation-as-state, layer boundaries.
paths: "**/*.swift"
---

# MVVM Architecture

MVVM (Model-View-ViewModel) on iOS gives every screen a single
source of truth and a single async-work owner. Reasoning about
a screen reduces to: "what does the ViewModel expose, and what
methods does the view call?" When a rule is unclear, see
`platforms/ios/docs/ios-architecture-mvvm-details.md`.

## The three roles

- `Model` -- plain value types (`struct`, `enum`) describing the
  domain. No reference to SwiftUI, no I/O behavior. Sendable.
- `View` -- SwiftUI views. Read ViewModel state, dispatch user
  actions as method calls. NEVER own business logic.
- `ViewModel` -- the screen's brain. Owns published state, owns
  the async lifecycle, calls into UseCase / Repository for I/O.

## ViewModel shape

- `final class ScreenViewModel: ObservableObject` -- or, on
  iOS 17+, `@Observable final class ScreenViewModel`.
- `@Published var state: ScreenState` (or `@Observable` property
  on iOS 17+) -- single state property the view reads.
- `@MainActor`-scoped at the class level when state is UI-bound.
- Async work owned by the ViewModel via `Task { ... }` started
  from `init` or from view-facing methods.

## Navigation as state

- A `Route` enum drives `NavigationStack`, `.sheet(item:)`, and
  `.fullScreenCover(item:)`. The view binds to `viewModel.route`.
- The ViewModel mutates `route` to navigate; the view observes
  and renders the appropriate destination.
- Modeling navigation as state means: deep links work, back
  navigation works, screenshot tests can reproduce any
  navigation state without driving a UI test.

## Layer boundaries -- no skipping

Layer order: View -> ViewModel -> UseCase -> Repository -> Service.

- View calls ONLY ViewModel methods.
- ViewModel calls ONLY UseCases (or, for simple screens,
  Repositories directly -- pick one and stay consistent).
- UseCase orchestrates one user-goal; calls Repositories.
- Repository abstracts a data source (network, disk, cache).
- Service is the concrete transport (URLSession, SwiftData,
  Keychain).

A view that reaches past its ViewModel into a Repository breaks
the layer model. The layer model is what makes the screen
testable.

## What goes where

- Business logic, validation, derivations -- in the ViewModel or
  a UseCase. NEVER in a View.
- I/O -- in a Repository, behind a protocol. The ViewModel sees
  only the protocol.
- Theme, layout, formatting strings for display -- in the View.
- Navigation -- as ViewModel state; the View binds to it.

## Why this discipline matters

Without a single state-and-navigation owner per screen, the
screen drifts toward "any view can mutate any thing," and the
state machine becomes invisible. With MVVM, a reader can answer
"how does this screen get into state X?" by reading the
ViewModel -- nothing else. Tests target the ViewModel directly:
inject fakes for UseCases, call methods, assert state.
