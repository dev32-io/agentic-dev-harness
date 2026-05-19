---
description: CSS -- modules or Tailwind, no global selectors, design tokens via custom properties.
paths: "**/*.css,**/*.tsx,**/*.jsx"
---

# CSS

The CSS approach is a project-wide choice: CSS Modules OR
Tailwind. Both are fine. Mixing them inside one codebase, on the
other hand, is the failure mode. When a rule is unclear, see
`platforms/web/docs/css-details.md`.

## Pick one styling system; document the choice

- CSS Modules and Tailwind both produce locally-scoped, low-
  conflict styles when used as intended. Either is acceptable.
- The project owner picks one in the README. New components use
  that system. Mixing both within a single codebase yields the
  worst of both worlds.
- One exception: a `reset.css` (or equivalent) and a global token
  sheet (custom properties) are global by necessity.

## No global selectors outside the reset

- Authored CSS uses module-scoped class selectors (CSS Modules)
  or utility classes (Tailwind). Naked element selectors
  (`button { ... }`, `h1 { ... }`) outside the reset are
  FORBIDDEN -- they leak across components.
- `:root` is reserved for design-token custom properties; do not
  put component styles there.
- Cross-cutting selectors (`*`, descendant combinators that
  reach into other components) are an explicit code smell.

## Design tokens via CSS custom properties

- All design tokens (colors, spacing, radii, typography scale,
  shadows, motion timing) are CSS custom properties on `:root`
  (or a theme-scoped element for dark mode / brand variants).
- Component styles consume tokens (`color: var(--color-primary)`);
  they do NOT hard-code hex values, pixel sizes, or duration
  literals.
- Naming: `--color-*`, `--space-*`, `--radius-*`, `--font-size-*`,
  `--shadow-*`, `--motion-*`. A grep on these prefixes finds the
  whole design system.

## Dark mode and theme variants

- Theme switching swaps the token sheet, not individual
  components. A `[data-theme="dark"]` (or `.dark`) selector on
  `<html>` re-binds the custom properties; component CSS does
  not change.
- This is what makes adding a third theme (e.g. high-contrast)
  a token-sheet edit, not a sweep through every component.

## Layout sizing -- relative units by default

- `rem` and `em` over `px` for typography and spacing that should
  respond to user preferences.
- Hard `px` is acceptable for hairline borders, 1-pixel grid
  alignment, and similar pixel-exact concerns.
- Container widths, font sizes, line heights: relative.

## Responsive design -- mobile first, breakpoints from tokens

- Author the base styles for the small viewport; add `min-width`
  media queries to layer on larger-viewport changes.
- Breakpoints come from tokens (`--bp-md`, `--bp-lg`) or
  Tailwind's screen scale, not magic numbers scattered through
  the codebase.

## Why this discipline matters

CSS has no module boundary by default. Global selectors and
hard-coded values are how a stylesheet becomes a 30,000-line
"don't touch" file. Modules-or-Tailwind + tokens + reset-only
globals keep the boundary explicit and changes local.
