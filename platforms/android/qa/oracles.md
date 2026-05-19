# Android QA Oracles

Heuristics a Reporter checks during an exploratory charter to decide whether observed behavior is a bug.

## Consistency oracles

- App icon and label match across launcher, recents, notifications, and settings. No "Activity1" placeholder in recents because someone forgot a `<activity-alias>`.
- Status bar color follows the theme. A light theme MUST NOT render a black status bar; a dark theme MUST NOT render a white status bar. The system bars are themed even on Android 15+ edge-to-edge.
- System back behavior is predictable. From a non-root screen, system back navigates up one level; it never exits the app unless the user is on the start destination.
- Empty states render with both copy AND a call-to-action. A bare "Nothing here." with no next step is a bug -- every empty state owes the user a verb.
- Loading states do not show stale content underneath. A skeleton or spinner replaces, doesn't overlay, the previous frame's data unless intentional (pull-to-refresh).

## State oracles

- Configuration change preserves screen state. Rotation, language switch, dark-mode toggle, and font-scale change all return to the same screen with the same scroll position, the same form contents, the same modal state.
- Process death + restore lands the user where they were, or one level up if the root has no `rememberSaveable`-shaped state. Open the app from the launcher with the process killed via `adb shell am force-stop` -- the user should not be punished for the OS reclaiming memory.
- Network loss → graceful empty state with retry. No system error dialog ("the application has stopped"); no infinite spinner; no silent blank screen. A persistent "no connection, retry" banner or empty state is the right shape.
- Permission denied is recoverable. If the user denies a runtime permission, the screen explains what's blocked and how to recover (re-prompt or deep-link to settings). It does not crash, freeze, or silently drop the user-initiated action.

## Performance oracles

- Cold start to first frame < 2s on a Pixel-class device (Pixel 6 / API 34+). Measure with `adb shell am start -W` (`TotalTime`).
- Scroll on the longest list in the app stays at 60fps. Jank ratio ≤ 1% of frames over a 10-second scroll (`adb shell dumpsys gfxinfo <pkg>`).
- No ANRs during the charter. The system must not show "App isn't responding" at any point.
- Memory does not grow unboundedly during a 10-minute exploratory session (`adb shell dumpsys meminfo <pkg>` before/after).

## Accessibility oracles

- Every interactive element has a `contentDescription` (or a `Modifier.semantics { contentDescription = ... }` in Compose). TalkBack must announce every tappable target.
- Tap targets are ≥ 48dp × 48dp. Smaller targets fail the WCAG 2.5.5 minimum.
- Color contrast meets WCAG AA on text (4.5:1 for body, 3:1 for large) and on essential UI icons. Use the Accessibility Scanner app or a contrast checker.
- TalkBack can navigate the full charter linearly. The screen-reader traversal order matches the visual reading order; nothing important is skipped; focus never gets trapped.

## Logging oracles

- No `CRASH` or `ANR` lines in `adb logcat` during the charter.
- No `Choreographer` skipped-frames warnings above 30 frames in a row (the system logs "Skipped N frames. The application may be doing too much work on its main thread"). Below 30 may be acceptable; above 30 is a stutter the user will feel.
- No `StrictMode` violations when running a debug build with strict mode enabled (disk reads on main, network on main, leaked closables).
- No "GC freed" lines clustered at app cold-start that imply allocation thrashing during init.
