# Web E2E with Playwright -- Details & Examples

This file expands `platforms/web/rules/e2e-playwright.md`.

## Where the matrix lives -- a worked example

A spec for "Cart -- empty state" might carry:

| Case                           | Viewport  | Pre-state            | Action               | Expected user-visible                                        | Expected log trail                |
| ------------------------------ | --------- | -------------------- | -------------------- | ------------------------------------------------------------ | --------------------------------- |
| see #empty-cart-fresh-visitor  | 1280x900  | logged-out, no cart  | navigate /cart       | "Your cart is empty" + CTA "Browse products"                 | route.view cart; no WARN          |
| see #empty-cart-fresh-visitor  | 390x844   | logged-out, no cart  | navigate /cart       | Same content, mobile layout (single column, CTA full-width)  | route.view cart; no WARN          |
| see #cart-restored-after-login | 1280x900  | items in guest cart  | log in               | Cart items still present, count badge unchanged              | cart.merge guest_to_user          |
| see #cart-restored-after-login | 390x844   | items in guest cart  | log in               | Same; bottom-tab cart badge updates                          | cart.merge guest_to_user          |

The `Case` column references catalog entries. The catalog entry
itself looks like:

```markdown
## #empty-cart-fresh-visitor

**Preconditions:** logged-out visitor; no cart cookie; clean
session storage.

**Steps:**
1. Navigate to /cart.

**Assertions:**
- Heading "Your cart is empty" is visible.
- "Browse products" link is visible and points at /products.
- No cart-item rows are rendered.
- No WARN or ERROR in the console.
```

## The MCP driver in an agent session

When the agent has a Playwright MCP server available, the
session-level flow looks like:

```pseudocode
# 1. Open the target URL at the matrix-row viewport.
playwright.browser_resize(width: 1280, height: 900)
playwright.browser_navigate("https://localhost:3000/cart")

# 2. Snapshot the accessibility tree -- this is what the agent
#    asserts on. The tree shape is stable across CSS refactors.
snap = playwright.browser_snapshot()

# 3. Assert on the snapshot.
assert snap.has(role: "heading", name: "Your cart is empty")
assert snap.has(role: "link", name: "Browse products")
assert snap.lacks(testid: "cart-item")

# 4. Capture evidence.
playwright.browser_take_screenshot(path: "qa/web/findings/cart-empty-desktop.png")
```

The accessibility-tree assertions and the screenshot together
form the evidence for the matrix row.

## The same case in `playwright test`

```ts
// tests/e2e/cart-empty.spec.ts
import { test, expect } from "@playwright/test";

const viewports = [
    { name: "desktop", width: 1280, height: 900 },
    { name: "mobile",  width: 390,  height: 844 },
];

for (const vp of viewports) {
    test(`empty-cart-fresh-visitor (${vp.name})`, async ({ page }) => {
        await page.setViewportSize({ width: vp.width, height: vp.height });
        await page.goto("/cart");

        await expect(page.getByRole("heading", { name: /your cart is empty/i }))
            .toBeVisible();
        await expect(page.getByRole("link", { name: /browse products/i }))
            .toBeVisible();
        await expect(page.getByTestId("cart-item")).toHaveCount(0);

        await page.screenshot({
            path: `qa/web/findings/cart-empty-${vp.name}.png`,
            fullPage: true,
        });
    });
}
```

The same selector strategy (`getByRole` + accessible name) works
in both the MCP driver and the test runner.

## Selectors -- the preference hierarchy

```ts
// 1. By accessible role + name. Best.
page.getByRole("button", { name: "Save" });

// 2. By label / placeholder / alt text. Good.
page.getByLabel("Email");

// 3. By test id. Acceptable for non-role'd elements.
page.getByTestId("cart-item");

// 4. By text. Brittle (locale, copy edits) but sometimes
//    unavoidable.
page.getByText("Browse products");

// 5. CSS / XPath. Last resort. A failing test here usually
//    means a CSS refactor, not a real regression.
page.locator(".css-1xyz");
```

## Auth, seeds, and the test stack

```ts
// Programmatic login -- not a UI flow. UI login has its own,
// separate test; every OTHER test starts at "logged in" via API.
test.beforeEach(async ({ request, context }) => {
    const session = await request.post("/api/test/seed-login", {
        data: { scenario: "user-with-items-in-cart" },
    });
    const { cookie } = await session.json();
    await context.addCookies([cookie]);
});
```

The `/api/test/...` endpoints are guarded by an env flag and
exist only in the test build. They make tests independent and
fast.

## Reduced-motion in tests

```ts
test.use({
    contextOptions: {
        reducedMotion: "reduce",
    },
});
```

For features that animate, run the same case once with reduced
motion to verify the no-motion path. The matrix row carries
that case explicitly.

## What goes in the catalog vs the spec

| In the catalog (testing-knowledge.md) | In the spec matrix          |
| ------------------------------------- | --------------------------- |
| Case name                             | Case name (reference)       |
| Preconditions                         | Viewport, pre-state pointer |
| Steps                                 | (omitted; in catalog)       |
| Assertions                            | (omitted; in catalog)       |
| Evidence convention                   | Evidence link per run       |

A new feature usually adds 1-3 cases to the catalog, plus uses
4-10 existing ones. If a feature adds 12 brand-new cases, that
is a signal -- either the catalog is too small (good problem,
keep going), or the cases are too feature-specific (bad sign,
generalize).

## Why this discipline matters

The same matrix runs from an agent session, from a developer
laptop, and from CI. The same cases serve multiple specs over
multiple quarters. The catalog is the institutional memory of
"what we test and how"; the spec matrix is the contract for
this particular feature. Playwright is the lever that makes
both executable.
