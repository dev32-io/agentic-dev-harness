# Charter 02 -- Configuration Change

## Mission

Verify the app preserves screen state across configuration changes -- the OS-level events (rotation, language switch, dark-mode toggle, font scale) that destroy and recreate Activities. State loss here is invisible to a unit test but obvious to a user.

## Time-box

30 minutes. Stop at the limit even if activities are incomplete; promote remaining work to a follow-up charter.

## Setup

- Real Pixel-class device or AVD on API 34+ with developer options enabled.
- Prime the app with non-trivial state before each activity: navigate at least two levels deep, scroll mid-list (not at top or bottom), open a modal or dialog if the screen has one, type partial text into any visible form field.
- `adb logcat -c` then leave a logcat tail running, filtered to the app's package, to watch for `CRASH`, `StrictMode`, or `Choreographer` warnings during the rotations.
- Reference: `platforms/android/qa/oracles.md` (state, consistency).

## Activities

1. **Rotate landscape ↔ portrait at 5 different screens.** Pick five screens that span the app's surface: a list, a detail, a form, a modal/dialog, and a settings screen. On each: prime state, rotate to landscape, validate, rotate back to portrait, validate. Validate after each rotation: same screen visible; scroll position preserved (within ± 1 visible item); form field contents preserved; cursor / focus in the same field if possible; open modal still open. Check oracles: *state* (configuration-change preservation), *consistency* (status bar and theme still correct in both orientations).

2. **Switch system language mid-session.** Pick a non-English locale (`Settings → System → Languages`). With the app open at a non-root screen, switch the system language. Return to the app. Validate: app strings re-localize; current screen preserved; user data (names, generated content) unchanged. Repeat by switching back to English. Check oracles: *state*, *consistency* (no English-only string leaks visible after switch).

3. **Toggle dark mode mid-screen.** With the app open, quick-settings → toggle dark mode. Validate: app switches themes immediately; current screen and scroll preserved; text contrast still passes the contrast oracle in the new theme; no flash of incorrectly-themed content; status bar icon color flips correctly. Repeat the reverse direction. Check oracles: *consistency* (theme correctness), *accessibility* (contrast in both themes).

4. **Bump font scale to 200%.** `Settings → Display → Font size → Largest` (typically 200%). With the app already open, return to the app. Validate: text reflows without clipping; no text overlaps; tap targets remain ≥ 48dp; buttons still readable, not truncated; modals/dialogs still readable. Reset to default after the activity. Check oracles: *accessibility* (font scale, tap-target size), *consistency* (no truncated strings).

## Notes

(Reporter fills this in during the session. Use RST-style `!` for confirmed bugs, `?` for "weird, not sure yet" items, `#` for setup / context / meta notes. Each note carries a timestamp and a one-line observation.)

## Findings

Promote any reproducible regression to a row in the feature spec's e2e matrix, referencing a case in `testing-knowledge.md`.
