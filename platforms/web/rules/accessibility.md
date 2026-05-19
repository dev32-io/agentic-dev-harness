---
description: Web accessibility -- semantic HTML first, keyboard nav, focus rings, reduced-motion respect.
---

# Web Accessibility

Accessibility is not a layer applied after the design. It is a
property of the HTML you write first. ARIA is a patch for when
the platform lacks the element you need; it is not a starting
point. When a rule is unclear, see
`platforms/web/docs/accessibility-details.md`.

## Semantic HTML FIRST, ARIA SECOND

- A `<button>` is a button. Use it. Do NOT use
  `<div onClick={...} role="button">` -- you re-implement focus,
  keyboard activation, disabled state, and form submission, and
  you get them all wrong.
- `<a href>` for navigation. `<button>` for actions in the
  current page. The two are NOT interchangeable.
- Use `<form>`, `<label>`, `<input>`, `<textarea>`, `<select>`,
  `<table>`, `<nav>`, `<main>`, `<header>`, `<footer>` for the
  thing they describe. The accessibility tree comes for free.
- ARIA attributes are for genuinely missing semantics (e.g. an
  application-specific widget). Every ARIA attribute added is a
  contract you must keep current.

## Keyboard navigability -- every interaction reachable

- Every interactive element MUST be reachable by Tab. The Tab
  order matches the visual reading order.
- Activation MUST work with Enter (for links and buttons) and
  with Space (for buttons, checkboxes, radios). The browser does
  this for native elements; verify it for custom components.
- Escape closes modals, popovers, and similar overlays. Trap
  focus inside modals; restore focus to the trigger on close.
- Mouse-only interactions (hover-reveal menus, drag-only
  reorder) MUST have a keyboard equivalent.

## Visible focus rings

- The focus indicator MUST be visible against any background.
  Hint: rely on the browser's default outline OR provide your
  own (`:focus-visible` selector); NEVER `outline: none` without
  an equivalent replacement.
- `:focus-visible` is preferred over `:focus` -- it shows the
  ring on keyboard navigation but suppresses it on mouse click,
  matching user expectations.

## Color contrast and color-only signals

- Body text meets WCAG AA contrast (4.5:1 normal, 3:1 large).
  The design tokens for color pairs MUST be verified together.
- Information conveyed by color also has a non-color cue (icon,
  text label, underline, pattern). "Red means error" alone fails
  for users who do not perceive red.

## Reduced motion -- respect the OS

- Animations and transitions MUST honor
  `@media (prefers-reduced-motion: reduce)` -- short or zero
  durations, no parallax, no auto-playing motion.
- Decorative animation is decoration. Communicative animation
  (a focus-state transition, a loading indicator) can still
  exist in reduced-motion mode, just at zero or near-zero
  duration.

## Forms -- labels are mandatory

- Every form control has an associated `<label>` (visible or
  `aria-labelledby`). Placeholder text is NOT a label; it
  vanishes on input.
- Error messages are associated with the field via
  `aria-describedby`; the field carries `aria-invalid="true"`.
- Submit-on-Enter works; that requires real `<form>` wrapping.

## Why this discipline matters

Semantic HTML is the single highest-leverage accessibility
choice. Every other rule here is recoverable; choosing `<div>`
over `<button>` is not -- the fix is "re-write the component."
The agent that starts with the right element ships a working
keyboard experience by default, not by audit.
