---
description: Web E2E with Playwright -- MCP driver, fixed viewports, testing-knowledge catalog references.
---

# Web E2E with Playwright

Web E2E is the concrete implementation of the matrix contract
declared in `base/rules/e2e-testing.md`. Playwright is the
driver. When a rule is unclear, see
`platforms/web/docs/e2e-playwright-details.md`.

## Playwright MCP is the agent's primary driver

- Inside an agent session, the Playwright MCP server is the
  preferred way to drive the browser. The agent sees a
  structured snapshot of the page (an accessibility-style tree)
  rather than raw HTML, which is what makes assertions stable.
- For CI or local headless runs, `playwright test` (the same
  underlying library) runs the same specs.
- The two share the page-object layer; the matrix rows are the
  same artifacts in both contexts.

## Fixed viewport matrix

- Desktop: `1280 x 900`. Mobile: `390 x 844`. These are the
  viewports declared by `base/rules/e2e-testing.md`; web tests
  inherit them.
- Every case runs at BOTH viewports unless the feature is
  mobile-only or desktop-only. The matrix row's `Viewport`
  column names which.
- Additional viewports (tablet, ultra-wide) are added only when
  the spec calls them out as load-bearing for the feature.

## Cases reference `testing-knowledge.md`, never duplicate

- The matrix `Case` column carries a short stable name (e.g.
  `empty-list-fresh-user`). The body of the case -- preconditions,
  steps, assertions -- lives in the target project's
  `agents/docs/testing-knowledge.md` catalog.
- New cases are appended to the catalog with the standard
  entry template. Per-spec matrices do not invent fresh case
  bodies inline -- that turns the catalog into a graveyard.
- The agent looking at a matrix row can grep the catalog for the
  case name and find the canonical definition.

## Screenshot per visual assertion

- Each row of the matrix that makes a visual claim captures a
  screenshot at the assertion point. The screenshot is the
  evidence; "I saw it work" is not.
- Screenshots live under `qa/<platform>/findings/<run-id>/` or
  similar -- the project decides the path. They are linked from
  the matrix row's evidence column.
- Visual-regression diffing is optional; what is NOT optional is
  the captured screenshot itself.

## Selector discipline

- Prefer role-based and accessible-name selectors:
  `page.getByRole("button", { name: "Save" })`. They survive
  refactors and double as accessibility assertions.
- Test IDs (`data-testid`) are acceptable for elements without a
  natural role/name (e.g. a styled drag handle).
- AVOID brittle CSS selectors (`.css-1xyz`), XPath, and
  text-only selectors when an accessible role exists.

## Real network, real auth -- not mocked

- E2E runs against a real running stack (see
  `base/rules/e2e-testing.md`). Mocked network is unit-test
  territory, not e2e.
- Test accounts are seeded by the project; the spec names the
  seed scenario it relies on.

## Why this discipline matters

The matrix is the contract; Playwright MCP is the driver that
makes the contract executable from inside an agent session. The
catalog reference + screenshot evidence makes "done" portable:
any agent or reviewer can replay the matrix and see the same
green.
