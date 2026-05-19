# iOS QA Oracles

Heuristics a Reporter checks during an exploratory charter to decide whether observed behavior is a bug.

## Consistency oracles

- App icon, label, and splash screen are consistent across SpringBoard (home screen), the App Switcher, Notification Center, and Spotlight. No "App-Beta" label leaking into a production build; no placeholder icon left in any surface.
- Status bar style adapts to the view's background. A light-content view MUST NOT show a dark status bar; a dark-content view MUST NOT show a light one. The `preferredStatusBarStyle` (UIKit) or `.toolbarColorScheme(...)` (SwiftUI) must match.
- Navigation bar back-button label matches the previous screen's title (or is intentionally truncated to "Back" when the previous title is long). A back button labeled with a stale or wrong screen name is a bug.
- Tab bar selection survives backgrounding. Backgrounding then re-foregrounding the app MUST NOT silently reset the selected tab to index 0.
- Modal-presentation style is consistent across the app. A `.sheet` and a `.fullScreenCover` MUST NOT be used interchangeably for the same kind of content; the choice is a product decision and should be applied uniformly.

## State oracles

- Rotation (where supported) preserves screen state. Scroll position, form contents, modal state, and selected segment all survive a portrait-landscape-portrait round trip. Apps that lock orientation are exempt -- the charter should verify the lock holds.
- Background -> foreground after a long absence (> 30 min) either restores state or lands the user one level up on the navigation stack. NEVER a crash, NEVER an empty home screen for a signed-in user.
- Memory-pressure simulation: Use Instruments' "Simulate Memory Warning" or `xcrun simctl ... memwarn`. On relaunch, the app restores user-meaningful state (or lands one level up) without losing signed-in identity.
- Network loss: graceful empty state with retry. NEVER a system-error dialog ("Cannot connect to server" iOS-style alert) bubbling up to the user; NEVER an infinite spinner. A persistent empty-state view with a Retry action is the correct shape.
- Permission denial is recoverable. Denying Camera / Location / Notifications produces an in-app screen that explains what is blocked and deep-links to Settings; the screen does not crash or silently drop the user-initiated action.

## Performance oracles

- Cold launch on iPhone 12 (or simulator equivalent) is under 2 seconds from icon tap to first interactive frame. Measure with Instruments' App Launch template.
- Scrolling on the longest list in the app stays at 60fps on a non-ProMotion device, or 120fps on a ProMotion device (iPhone Pro 13+). Use Instruments' Animation Hitches template or the FPS HUD.
- Hang ratio in the Xcode Organizer (TestFlight + production builds) is below 1% over the charter session.
- No memory warnings observed in normal flows. The console MUST NOT show "Received memory warning" during a 10-minute exploratory session through normal screens.

## Accessibility oracles

- VoiceOver: every screen is navigable. Every interactive control is announced with a meaningful label (NOT just "Button"). The rotor's headings / form controls / links groupings make sense.
- Dynamic Type: layout adapts up to "Accessibility Large" (`accessibility3`) without clipping, overlap, or unreachable controls. Test with the Accessibility Inspector or the Settings -> Accessibility -> Display & Text Size -> Larger Text slider at max.
- Color contrast meets WCAG AA (4.5:1 for body text, 3:1 for large text and essential UI icons) in both light and dark mode. Check with Accessibility Inspector's Color Contrast Audit.
- Tap targets are >= 44pt x 44pt. Smaller targets fail Apple's Human Interface Guidelines minimum.
- "Reduce Motion" is honored. With Reduce Motion enabled (Settings -> Accessibility -> Motion), the app does not present parallax effects, slide-from-edge transitions, or other animations beyond simple fades. No motion surprises.

## Logging oracles

- No `os.Logger` lines at `.error` or `.fault` level emitted during a clean charter walkthrough. Filter the Console.app stream on the app's bundle identifier and watch the level column.
- No "App Transport Security has blocked a cleartext HTTP" warnings. All endpoints are HTTPS; if a cleartext exception is needed, it is documented in `Info.plist` with a real reason.
- No Main Thread Checker violations. The Main Thread Checker is enabled by default in debug; any violation prints "PID: ... Main Thread Checker: ..." to the console and is a confirmed bug.
- No Thread Sanitizer warnings during testing (when TSan is enabled in the scheme). Race conditions caught by TSan are confirmed bugs regardless of observable user impact.
