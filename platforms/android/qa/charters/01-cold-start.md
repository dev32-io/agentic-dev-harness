# Charter 01 -- Cold Start

## Mission

Verify the cold-start path is correct, performant, and produces no leaked state across the three entry conditions a real user hits: fresh install, post-update launch, and post-clear-data launch.

## Time-box

45 minutes. Stop at the limit even if activities are incomplete; promote remaining work to a follow-up charter.

## Setup

- Real Pixel-class device or AVD on API 34+ with the latest signed debug build.
- `adb logcat -c` to clear the log before each activity.
- Open `adb logcat` in a side terminal filtered to the app's package + `ActivityManager`.
- `adb shell am start -W` ready to measure cold-start time.
- Reference: `platforms/android/qa/oracles.md` (consistency, state, performance, logging).

## Activities

1. **Fresh install → launch → first-run screen.** Uninstall the app. `adb install` the APK. Launch from the launcher (not via `adb shell am start`, to mimic a user). Validate: app icon and label correct in launcher; first-run / onboarding screen renders; status bar theme correct; `am start -W TotalTime` < 2000ms. Check oracles: *consistency* (icon, label, status bar), *performance* (cold-start time).

2. **Background → restart → land on previously-open screen.** Navigate two levels deep (e.g., home → list → detail). Press the home button to background the app. Wait 30 seconds. Re-launch from recents. Validate: app returns to the detail screen (not the home screen); scroll position preserved; any open modal preserved. Check oracles: *state* (configuration-change-style preservation across backgrounding).

3. **Clear data → relaunch → first-run again, no leaked data.** `adb shell pm clear <package>`. Relaunch from launcher. Validate: app shows the first-run / onboarding flow again (not the post-onboarding home); no prior user's name, avatar, or cached content visible anywhere; no stale notification still showing. Check oracles: *state* (no leakage), *consistency* (empty states render correctly on a truly empty install).

4. **Post-update simulation -- migration runs silently.** Install v1 of the app (or the current build). Generate non-trivial state (sign in, create at least one durable record). Background. `adb install -r` an artifact pretending to be v2 (or the same build to simulate the migration path). Relaunch. Validate: user is not signed out; existing records are still visible; no migration error dialog; no spike in cold-start time beyond the 2s budget. Check oracles: *state* (data preserved across update), *performance* (migration does not block first frame > budget).

## Notes

(Reporter fills this in during the session. Use RST-style `!` for confirmed bugs, `?` for "weird, not sure yet" items, `#` for setup / context / meta notes. Each note carries a timestamp and a one-line observation.)

## Findings

Promote any reproducible regression to a row in the feature spec's e2e matrix, referencing a case in `testing-knowledge.md`.
