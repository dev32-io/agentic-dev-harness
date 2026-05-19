---
description: Xcode build conventions -- xcconfig files, shared schemes, xcodebuild for CI.
paths: "**/*.swift"
---

# Xcode Build Conventions

Xcode's project file (`.xcodeproj`) is a tarpit -- a binary-ish
XML format that diff-merges badly and hides build settings from
review. The conventions below keep build configuration in
plain-text files that diff cleanly. When a rule is unclear, see
`platforms/ios/docs/ios-xcodebuild-details.md`.

## Build settings live in `.xcconfig`

- ALL build settings (deployment target, Swift version, search
  paths, defines, signing identity defaults) live in `.xcconfig`
  files in the repo, NOT inside the `.xcodeproj` blob.
- One xcconfig per target + configuration combo, or a layered
  set (`Common.xcconfig` -> `App.xcconfig` -> `App.Debug.xcconfig`).
- The project file references the xcconfig at the Project and
  Target build-config level; no settings inline.

## Schemes are shared and checked in

- Every CI-built scheme MUST be marked Shared (the
  `xcshareddata/xcschemes/*.xcscheme` files end up in git).
- A scheme not in git cannot be built by CI -- the build is
  reproducible only on the developer's machine. Schemes belong
  in the repo.
- Personal user-level schemes go in `xcuserdata/` which is
  gitignored.

## `xcodebuild` is the build, not Xcode

- CI builds via `xcodebuild build` / `xcodebuild test` -- never
  via Xcode's GUI. The CI command is the contract.
- NEVER depend on Xcode's "implicit dependency" graph for CI
  builds. List dependencies explicitly so `xcodebuild` produces
  the same artifact whether the developer hit Cmd-B yesterday
  or not.
- The CI invocation includes `-scheme`, `-destination`,
  `-configuration`, `-derivedDataPath`, and (usually)
  `-resultBundlePath` for downstream test reporting.

## Code signing

- Development builds use Xcode's automatic signing with a Team
  ID committed in the xcconfig: `DEVELOPMENT_TEAM = ABCD1234EF`.
- Release builds use Manual signing with the provisioning
  profile NAME committed in the xcconfig:
  `PROVISIONING_PROFILE_SPECIFIER = AppStore-Distribution`.
  The actual profile file is fetched by CI from secret storage
  (App Store Connect API, fastlane match, etc.) -- NEVER
  checked into git.
- Certificates and profiles MUST NOT be in the repo. Anything
  signing-key-shaped is a leak.

## Dependencies

- Swift Package Manager dependencies are preferred. They live in
  `Package.swift` (for SPM packages) or in the project file's
  `XCPackageReference` (for app projects -- still semi-textual).
- CocoaPods is acceptable for legacy code but new dependencies
  prefer SPM. Lock `Package.resolved` (committed) for repeatable
  builds.
- Vendored binaries (`.xcframework`) belong in a versioned
  subdirectory, NEVER scattered. A `Frameworks/` folder with a
  README pointing at the source.

## Why this discipline matters

The Xcode project file is the single biggest source of "works
on my machine" in iOS development. Pulling settings into
xcconfigs, sharing schemes, and running `xcodebuild` from CI
turns the build into a thing the team can reason about, diff,
and reproduce on a fresh checkout.
