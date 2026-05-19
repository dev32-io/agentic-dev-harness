# Charter 01 -- Cold Launch

## Mission

Verify the cold-launch path is correct, performant, and produces no leaked state across the three entry conditions a real user hits: fresh install, post-update launch, and post-clear-data launch.

## Time-box

45 minutes. Stop at the limit even if activities are incomplete; promote remaining work to a follow-up charter.

## Setup

- iPhone simulator (Pixel-of-iOS-equivalent: iPhone 15 on the latest iOS) or a real device on iOS 17+.
- Latest signed debug build installed.
- Console.app open and filtered to the app's bundle identifier so the Reporter sees `os.Logger` output live.
- Instruments' App Launch template ready to attach for the cold-launch performance measurement.
- Reference: `platforms/ios/qa/oracles.md` (consistency, state, performance, logging).

## Activities

1. **Fresh install -> launch -> first-run screen.** Uninstall the app (long-press icon -> Remove App, or `xcrun simctl uninstall booted <bundle-id>`). Reinstall from Xcode or via `xcrun simctl install booted <path>`. Launch from SpringBoard by tapping the icon -- NOT from Xcode's run button, to mimic a real user's first launch. Validate: app icon and label render correctly on SpringBoard; splash screen displays; first-run / onboarding screen renders; status bar style is correct for the first screen; cold-launch time per Instruments' App Launch template is under 2000ms (under "Launch -> First Frame"). Check oracles: *consistency* (icon, label, status bar), *performance* (cold-launch time).

2. **Background -> foreground -> land on previously-open screen.** Navigate two levels deep (e.g., home -> list -> detail). Background the app via swipe-up gesture. Wait 30 seconds. Foreground via SpringBoard or App Switcher. Validate: app returns to the detail screen, NOT the home screen; scroll position preserved within +/- 1 visible cell; any open modal still presented; bottom tab selection unchanged. Check oracles: *state* (preservation across backgrounding).

3. **Clear data -> relaunch -> first-run again, no leaked data.** Uninstall + reinstall the app (the iOS equivalent of "clear data" since iOS does not expose a direct clear-data action). Relaunch from SpringBoard. Validate: app shows the first-run / onboarding flow (NOT the post-onboarding home); no prior user's name, avatar, or cached content is visible anywhere; no stale notification still pinned in Notification Center; Keychain has no leftover credentials (re-prompt for sign-in occurs). Check oracles: *state* (no leakage), *consistency* (empty states render correctly).

4. **Post-update simulation -- migration runs silently.** Install v1 of the app (or the current build). Generate non-trivial state: sign in, create at least one durable record, browse a content tab to populate caches. Background. Install v2 (or the same build, simulating an update path) via `xcrun simctl install booted <path>` -- the install replaces without uninstalling, preserving Documents/Library. Relaunch. Validate: user is not signed out; existing records still visible; no migration error alert; Core Data / SwiftData migration completes without prompting the user; cold-launch time still under the 2s budget despite migration. Check oracles: *state* (data preserved across update), *performance* (migration does not blow the first-frame budget).

## Notes

(Reporter fills this in during the session. Use RST-style `!` for confirmed bugs, `?` for "weird, not sure yet" items, `#` for setup / context / meta notes. Each note carries a timestamp and a one-line observation.)

## Findings

Promote any reproducible regression to a row in the feature spec's e2e matrix, referencing a case in `testing-knowledge.md`.
