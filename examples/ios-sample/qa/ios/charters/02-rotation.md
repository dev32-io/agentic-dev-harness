# Charter 02 -- Rotation

## Mission

Verify the app behaves correctly under device rotation. iOS-specific note: many iOS apps lock to portrait orientation by design. If the target app locks portrait, this charter becomes "verify the lock holds across all screens, and document that landscape support is intentionally out of scope." For apps that support rotation, verify state is preserved across rotation at a representative set of screens.

## Time-box

30 minutes. Stop at the limit even if activities are incomplete; promote remaining work to a follow-up charter.

## Setup

- iPhone simulator on iOS 17+ (the Simulator's Hardware menu has Rotate Left / Rotate Right shortcuts, or use Cmd-Left / Cmd-Right), or a real device with rotation lock OFF in Control Center.
- Confirm up front whether the app supports rotation: check `UISupportedInterfaceOrientations` in `Info.plist` (or `supportedInterfaceOrientations` overrides in the root view controllers). If only portrait orientations are listed, the charter pivots to "verify the lock."
- Prime the app with non-trivial state before each activity: navigate at least two levels deep, scroll mid-list, open a modal if the screen has one, type partial text into a visible form field.
- Console.app open, filtered to the app's bundle identifier, to watch for Main Thread Checker warnings or `os.Logger` errors during rotations.
- Reference: `platforms/ios/qa/oracles.md` (state, consistency, accessibility).

## Activities

**Branch A -- if the app locks portrait orientation:**

1. **Verify the portrait lock holds.** Walk through every screen the app exposes (home, list, detail, modal, settings, login). Rotate the simulator at each. Validate: the layout does NOT rotate; the status bar does NOT rotate; no view appears in landscape briefly before snapping back. Check oracles: *consistency* (orientation behavior uniform across screens).

2. **Document the intentional scope.** Record in the Findings section that landscape support is out of scope per the `Info.plist` declaration, citing the orientation array. Any landscape behavior observed despite the lock is a bug.

**Branch B -- if the app supports rotation:**

1. **Rotate landscape <-> portrait at 5 different screens.** Pick five screens that span the app's surface: a list, a detail, a form, a modal/dialog, and a settings screen. On each: prime state, rotate to landscape, validate, rotate back to portrait, validate. Validate after each rotation: same screen visible; scroll position preserved within +/- 1 visible cell; form field contents preserved; cursor / focus in the same field if possible; open modal still open; status bar style still correct. Check oracles: *state* (rotation preservation), *consistency* (status bar in both orientations).

2. **Toggle Dynamic Type mid-screen, then rotate.** Settings -> Accessibility -> Display & Text Size -> Larger Text. Bump the slider to "Accessibility Large" (`accessibility3`) while the app is open. Return to the app. Rotate. Validate: text reflows without clipping in BOTH orientations; tap targets remain >= 44pt; modals readable in landscape; no truncated strings. Reset to default after the activity. Check oracles: *accessibility* (Dynamic Type, tap-target size), *state* (rotation under accessibility settings).

3. **Toggle dark mode mid-screen, then rotate.** Quick-toggle dark mode (Settings -> Display & Brightness, or via Control Center shortcut if configured). Validate: app switches themes immediately; current screen and scroll preserved; text contrast still passes the contrast oracle in the new theme; status bar style flips correctly. Then rotate. Validate: theme remains correct in landscape; no flash of incorrectly-themed content during the rotation. Check oracles: *consistency* (theme correctness across orientation), *accessibility* (contrast in both themes).

## Notes

(Reporter fills this in during the session. Use RST-style `!` for confirmed bugs, `?` for "weird, not sure yet" items, `#` for setup / context / meta notes. Each note carries a timestamp and a one-line observation.)

## Findings

Promote any reproducible regression to a row in the feature spec's e2e matrix, referencing a case in `testing-knowledge.md`.
