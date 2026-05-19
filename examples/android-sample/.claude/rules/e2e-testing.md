---
description: Every spec and plan MUST contain a concrete e2e test matrix. A feature is not done until every row is green.
---

# End-to-End Testing

E2E testing is part of feature development, not a follow-up step.
When a rule is unclear, see `base/docs/e2e-testing-details.md`.

## Spec / plan contract: matrix or it's not a spec

- Every spec AND every implementation plan MUST contain a concrete
  e2e test matrix. A document without a matrix is not a valid spec
  or plan — it is a wish.
- The matrix is the contract that makes "done" mechanically
  verifiable by any other model or human reviewer.

## Canonical matrix shape

- The matrix is a table. Columns are FIXED in this order:
  `Case | Viewport | Pre-state | Action | Expected user-visible | Expected log trail`
- See `base/docs/e2e-testing-details.md` for the canonical example,
  viewport conventions, and driver recommendations.

## Source of cases: the project's catalog

- Reusable cases live in the target project's
  `agents/docs/testing-knowledge.md` catalog.
- Per-spec matrices REFERENCE cases by stable short name (e.g.
  `see testing-knowledge.md#empty-list-fresh-user`). They do NOT
  duplicate case bodies into the spec.
- New reusable cases are appended to the catalog with the standard
  entry template. The catalog is the single source of truth.

## Cover happy AND sad paths, and the viewport matrix

- Run every case at both viewports unless the feature is desktop-
  only or mobile-only: `desktop` = 1280×900, `mobile` = 390×844.
- Cover edge paths — empty states, error fallbacks, concurrent
  actions, reconnect, cross-tab where applicable. Layout
  regressions land where the agent didn't look.

## A case is green only when the full trail matches

- User-visible behavior matches the expected column.
- Log / console trail matches the expected log column. No unexpected
  WARN or ERROR. A passing UI screenshot with warning noise in the
  console is not green.
- Evidence is captured: screenshots at decision points, log
  excerpts, network requests where contract matters.

## Pre-handover gate

Before declaring a feature done, ALL of the following must hold:

1. Every matrix row green.
2. Evidence captured per row (screenshots / log excerpts).
3. Lint clean.
4. Typecheck clean.
5. Unit tests clean.
6. Deployable artifact built.

No partial green. No "we'll fix it next sprint." If a row is red,
the feature is not done.

## Unreachable cases: flag explicitly, never silently drop

- If a case cannot be exercised by the chosen driver (e.g.
  Playwright cannot exercise a native iOS gesture; a real-device
  sensor permission cannot be granted in CI), flag it in the
  handover for operator / user follow-up.
- Never silently drop a case from the matrix. The matrix is the
  audit trail.

## Drive real stacks, not mocks

- E2E runs against a real running stack. Mocks belong in unit
  tests. Mocked e2e provides no defense against integration
  regressions.
- Use the project's free or test credentials for setup. Do not burn
  paid services in e2e unless the feature specifically depends on
  them.

## Why this discipline matters

The matrix is the contract. Any other model or human can pick up
the spec, run the matrix, and verify "done" mechanically. Plans
become portable. Reviews become evidence-based. "Looks good to me"
is replaced by "6 of 6 rows green, evidence linked."
