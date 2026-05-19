# CSS -- Details & Examples

This file expands `platforms/web/rules/css.md`.

## CSS Modules in practice

```tsx
// Card.tsx
import styles from "./Card.module.css";

export function Card({ children }: { children: React.ReactNode }) {
    return <div className={styles.root}>{children}</div>;
}
```

```css
/* Card.module.css */
.root {
    padding: var(--space-4);
    border-radius: var(--radius-md);
    background: var(--color-surface);
    color: var(--color-on-surface);
    box-shadow: var(--shadow-sm);
}
```

The class name `.root` is locally scoped; the bundler rewrites
it to something like `Card_root__hAj3K`. No collision with
another component's `.root`.

## Tailwind in practice

```tsx
export function Card({ children }: { children: React.ReactNode }) {
    return (
        <div className="rounded-md bg-surface text-on-surface p-4 shadow-sm">
            {children}
        </div>
    );
}
```

Tailwind's utility classes are themselves bound to design tokens
via the Tailwind config:

```js
// tailwind.config.js
export default {
    theme: {
        extend: {
            colors: {
                surface:    "var(--color-surface)",
                "on-surface": "var(--color-on-surface)",
                primary:    "var(--color-primary)",
            },
        },
    },
};
```

The Tailwind config and the CSS custom-property sheet are the
same source of truth, expressed twice for the JIT compiler. The
ground truth remains `:root`.

## The token sheet

```css
/* tokens.css -- imported once at the app root. */
:root {
    /* Color */
    --color-primary:        oklch(62% 0.18 250);
    --color-on-primary:     oklch(99% 0 0);
    --color-surface:        oklch(99% 0 0);
    --color-on-surface:     oklch(20% 0.02 250);
    --color-danger:         oklch(60% 0.20 25);

    /* Spacing -- 4px scale */
    --space-1: 0.25rem;
    --space-2: 0.5rem;
    --space-3: 0.75rem;
    --space-4: 1rem;
    --space-6: 1.5rem;
    --space-8: 2rem;

    /* Radii */
    --radius-sm: 0.25rem;
    --radius-md: 0.5rem;
    --radius-lg: 1rem;

    /* Typography */
    --font-size-sm:  0.875rem;
    --font-size-md:  1rem;
    --font-size-lg:  1.25rem;
    --font-size-xl:  1.5rem;

    /* Motion */
    --motion-fast:   120ms;
    --motion-normal: 200ms;
    --motion-slow:   320ms;
}

[data-theme="dark"] {
    --color-surface:    oklch(18% 0.02 250);
    --color-on-surface: oklch(95% 0.01 250);
    /* Only the tokens that change between themes are listed. */
}
```

To add a high-contrast theme, add a `[data-theme="hc"]` block
that re-binds the relevant tokens. Component CSS is untouched.

## Reset and global sheet

```css
/* reset.css -- the ONLY place where naked element selectors are OK. */
*, *::before, *::after { box-sizing: border-box; }

html, body { margin: 0; padding: 0; }

button {
    font: inherit;
    background: none;
    border: 0;
    cursor: pointer;
}

a { color: inherit; text-decoration: none; }

img, picture, video, svg { display: block; max-width: 100%; }
```

Outside `reset.css`, naked element selectors are a code-review
reject.

## The anti-patterns

```css
/* WRONG -- naked element selector in a feature stylesheet.
   Now every <button> in the app gets this padding, including
   ones the author never saw. */
button {
    padding: 12px 24px;
}

/* WRONG -- hard-coded color, hard-coded spacing.
   Theming requires editing every site that did this. */
.card {
    background: #ffffff;
    color: #111111;
    padding: 16px;
}

/* WRONG -- descendant combinator reaching into another
   component's internals. */
.parent .child-button { background: red; }
```

The corrected forms:

```css
/* Module-scoped class, all values from tokens. */
.card {
    background: var(--color-surface);
    color:      var(--color-on-surface);
    padding:    var(--space-4);
}
```

## Responsive -- mobile first

```css
.grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--space-4);
}

@media (min-width: 48rem) {           /* tablet */
    .grid { grid-template-columns: 1fr 1fr; }
}

@media (min-width: 64rem) {           /* desktop */
    .grid { grid-template-columns: repeat(3, 1fr); }
}
```

Breakpoint values live in tokens or the Tailwind config, not
sprinkled as magic numbers.

## Reduced motion

```css
@media (prefers-reduced-motion: reduce) {
    * {
        animation-duration:   0.01ms !important;
        animation-iteration-count: 1 !important;
        transition-duration:  0.01ms !important;
    }
}
```

That short block in `reset.css` (or a dedicated global) honors
the user's OS preference. See also `accessibility.md`.

## Why tokens pay off in two months

Without tokens: "make the primary color slightly more saturated"
is a sweep across the codebase, easy to half-finish. With
tokens: one line in `tokens.css`. The agent that picks up the
codebase in two months is grateful for that one line.
