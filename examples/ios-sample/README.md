# examples/ios-sample

Minimal SwiftUI project pre-wired with the agentic-dev-harness rule + hook system. Demonstrates the post-install state with a working `@Observable` counter screen.

## What's here

- `CounterViewModel` (`@Observable @MainActor`) with optimistic `count` + transient `toast`.
- `ContentView` owns the VM via `@State`; `#Preview` included.
- Swift Testing target (`Tests/CounterViewModelTests.swift`) — `@Test` + `#expect`.
- xcodegen `project.yml` committed; Swift 6 strict concurrency.

## Toolchain

- Swift 6.0 / iOS 17.0 deployment target / Xcode 16+.
- `SWIFT_STRICT_CONCURRENCY = complete` enabled.
- xcodegen 2.45.4 generates `App.xcodeproj` from `project.yml`.

## To build + test locally

```
xcodegen generate
xcodebuild -project App.xcodeproj -scheme App \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build test CODE_SIGNING_ALLOWED=NO
```

Or via the quality gate:

```
sh scripts/quality-gate.sh all
```
