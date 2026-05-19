# Web Accessibility -- Details & Examples

This file expands `platforms/web/rules/accessibility.md`.

## The `<button>` vs `<div role="button">` trap

```tsx
// WRONG -- you re-implement and get half of it wrong.
<div role="button" tabIndex={0} onClick={onPress}>
    Save
</div>

// Things you forgot:
// - Enter and Space activation (must handle onKeyDown)
// - Disabled state styling AND non-interaction
// - Form submission semantics (this won't submit a form)
// - Default browser focus ring
// - Screen reader announcing "button" with correct state changes
```

```tsx
// RIGHT.
<button type="button" onClick={onPress}>
    Save
</button>

// If it submits a form: <button type="submit">.
// If it cancels a form: <button type="button">.
// type defaulting to "submit" inside a <form> bites everyone once.
```

## Links vs buttons -- the decision

```tsx
// Navigation to a new URL -- it's a link, even if styled as a button.
<a href="/products/42">View product</a>

// Action on the current page -- it's a button, even if it looks
// like a link.
<button type="button" onClick={addToCart}>Add to cart</button>
```

Rule of thumb: if you put the destination in `href`, it's a
link. Right-click + "Open in new tab" should work for links; it
should not work for buttons.

## Modal focus management

```tsx
function Modal({ isOpen, onClose, children }: Props) {
    const triggerRef = useRef<HTMLElement | null>(null);
    const dialogRef  = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (!isOpen) return;
        triggerRef.current = document.activeElement as HTMLElement;
        dialogRef.current?.focus();
        return () => triggerRef.current?.focus();
    }, [isOpen]);

    useEffect(() => {
        if (!isOpen) return;
        const onKey = (e: KeyboardEvent) => {
            if (e.key === "Escape") onClose();
        };
        document.addEventListener("keydown", onKey);
        return () => document.removeEventListener("keydown", onKey);
    }, [isOpen, onClose]);

    if (!isOpen) return null;
    return (
        <div
            ref={dialogRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby="modal-title"
            tabIndex={-1}
        >
            <h2 id="modal-title">Title</h2>
            {children}
        </div>
    );
}
```

Properties:
- Focus moves into the modal on open.
- Focus returns to the trigger on close.
- Escape closes.
- The modal carries `role="dialog"` and `aria-modal="true"`.
- Focus is *trapped* inside the modal (omitted here -- use a
  small focus-trap utility or library).

## Visible focus -- `:focus-visible`

```css
button:focus-visible {
    outline: 2px solid var(--color-primary);
    outline-offset: 2px;
}

/* No `:focus` style without `:focus-visible` -- the browser's
   `:focus-visible` heuristic suppresses the ring on mouse clicks
   and shows it on keyboard navigation. */
```

```css
/* WRONG. */
button:focus { outline: none; }
/* You just made every keyboard user invisible. */
```

If you must remove the default outline, REPLACE it:

```css
button:focus { outline: none; }
button:focus-visible {
    box-shadow: 0 0 0 3px var(--color-focus-ring);
}
```

## Form labels

```tsx
// RIGHT -- visible label associated by `htmlFor`.
<label htmlFor="email">Email</label>
<input id="email" type="email" name="email" />

// RIGHT -- visually hidden but screen-reader visible.
<label htmlFor="search" className="sr-only">Search</label>
<input id="search" type="search" name="q" placeholder="Search" />

// WRONG -- placeholder instead of label.
<input type="email" placeholder="Email" />
// Vanishes on input. Low-contrast in most defaults. Screen
// readers may or may not announce it.
```

Error state:

```tsx
<label htmlFor="email">Email</label>
<input
    id="email"
    aria-describedby={error ? "email-error" : undefined}
    aria-invalid={Boolean(error)}
/>
{error && (
    <p id="email-error" role="alert">{error}</p>
)}
```

## Color contrast -- pair tokens, verify together

When a token pair is introduced (e.g. `--color-surface` /
`--color-on-surface`), the contrast ratio between them is
verified once at design-system definition. Component code then
uses the pair; it does not re-verify per component.

A contrast checker (e.g. axe, lighthouse, or a CSS tooling step)
runs in CI on the token sheet.

## Color + secondary cue

```tsx
// WRONG -- red border is the ONLY signal.
<input className={hasError ? "border-red" : ""} />

// RIGHT -- icon + text + color.
<input className={hasError ? "border-red" : ""} aria-invalid={hasError} />
{hasError && (
    <p role="alert">
        <Icon name="error" aria-hidden="true" /> {errorMessage}
    </p>
)}
```

## Reduced motion in components

```tsx
function Toast({ children }: Props) {
    const prefersReduced = useMediaQuery("(prefers-reduced-motion: reduce)");
    return (
        <div
            className="toast"
            style={{
                transitionDuration: prefersReduced ? "0ms" : "200ms",
            }}
        >
            {children}
        </div>
    );
}
```

Or, more often, handle it at the CSS layer:

```css
.toast {
    transition: opacity var(--motion-normal);
}
@media (prefers-reduced-motion: reduce) {
    .toast { transition-duration: 0.01ms; }
}
```

## Accessibility in the E2E matrix

The `e2e-playwright.md` rule references `testing-knowledge.md`
cases. A11y-relevant cases that belong in the catalog:

- `keyboard-tab-order-flow-X` -- Tab through the whole flow.
- `modal-focus-return` -- open modal, close, focus returns.
- `form-error-announced` -- submit invalid form, error linked.
- `reduced-motion-toggle` -- simulate the preference, verify.

The agent that ships a new screen adds those cases to the
catalog OR references existing ones in the matrix.
