# examples/ios-sample

Minimal SwiftUI project pre-wired with the agentic-dev-harness rule + hook system.

## What's here

- Minimal SwiftUI app — single `ContentView` rendering "agentic-dev-harness ios sample" with a `#Preview`.
- One XCTest smoke test (`Tests/ContentViewModelTests.swift`).
- `project.yml` (xcodegen spec) — committed so users can regenerate `App.xcodeproj` locally.
- `App.xcodeproj/` — committed generated project (built with xcodegen 2.45.4 against Xcode 16). Regenerate any time with `xcodegen generate`.
- `App/Info.plist` — xcodegen-managed; safe to edit but xcodegen will overwrite keys it manages on regeneration.
- `.claude/rules/` and `agents/docs/` from `sh install.sh --target . --platforms ios` (chain pulls in `mobile`).
- `qa/ios/oracles.md` + sample charters under `qa/ios/charters/`.

## Build verification status

Verified locally on the harness host:

```
xcodebuild -project App.xcodeproj -scheme App \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO -quiet
# Exit: 0
```

(Xcode 16.2, xcodegen 2.45.4.)

## To run locally

Requires: Xcode 16+ and (optionally) `xcodegen` (`brew install xcodegen`) if you want to rebuild the xcodeproj from `project.yml`.

```
xcodegen generate                   # optional — regenerate App.xcodeproj from project.yml
sh scripts/quality-gate.sh all      # full gate
```

`scripts/quality-gate.sh` auto-detects this as iOS (sees `*.xcodeproj`) and runs `xcodebuild build && xcodebuild test`. Note: the bundled `quality-gate.sh` invokes `xcodebuild` without `-scheme`/`-destination`; for a real CI run you'll want to wrap it (or rely on the iOS-specific `platforms/ios/hooks/quality-gate-ios.sh` once you wire it in).

## How it was set up

1. Hand-scaffolded the SwiftUI app + XCTest target + xcodegen `project.yml`.
2. Ran `xcodegen generate` to produce `App.xcodeproj`.
3. From the harness repo root: `sh install.sh --target examples/ios-sample --platforms ios`.
4. Verified the harness landed: `.claude/rules/ios/`, `.claude/rules/mobile/` (chained), `agents/docs/ios/`, `qa/ios/oracles.md`, `scripts/quality-gate.sh`.
5. Verified the build with `xcodebuild ... build` against the iPhone simulator SDK (exit 0).
