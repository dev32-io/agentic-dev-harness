# E2E Testing — Details, Matrix Shape, and Catalog Discipline

This file expands `base/rules/e2e-testing.md`. The rule defines the
bar; this doc shows the canonical matrix shape, viewport conventions,
driver choices per platform, and the catalog discipline that keeps
specs portable.

## Why a matrix is non-negotiable

A feature without an e2e matrix has no enforceable definition of
done. Any reviewer — human or model — needs a deterministic checklist
to verify behavior. Prose like "the empty state should look right"
cannot be checked mechanically; a matrix row can.

The matrix is what makes plans portable across agents and people.
It's the shared contract between whoever wrote the spec and whoever
verifies it.

## Canonical matrix shape (generic example)

Every spec defines its e2e matrix as a table with these 6 columns,
in this exact order:

```markdown
| Case                              | Viewport       | Pre-state         | Action                              | Expected user-visible              | Expected log trail                |
|-----------------------------------|----------------|-------------------|-------------------------------------|------------------------------------|-----------------------------------|
| Empty list, fresh user            | desktop+mobile | no records exist  | open list view                      | empty-state copy renders           | no WARN / ERROR                   |
| Login with valid credentials      | desktop+mobile | logged out        | submit valid email + password       | redirected to dashboard            | one INFO: `auth.login.success`    |
| Login with bad password           | desktop        | logged out        | submit valid email + bad password   | inline error renders, focus stays  | one WARN: `auth.login.invalid`    |
| Session expiry during use         | desktop        | logged in, idle   | wait past session TTL, then click   | redirect to login, banner shows    | one INFO: `auth.session.expired`  |
```

The 6 columns are fixed because each one answers a different
question:

- **Case** — the stable name; references the catalog entry.
- **Viewport** — desktop, mobile, or both.
- **Pre-state** — what must be true before the action runs.
- **Action** — the single user-visible action under test.
- **Expected user-visible** — what the user sees post-action.
- **Expected log trail** — what the logs / console must (or must
  not) contain. This is what catches silent regressions.

## Viewport conventions

Run every case at both viewports unless the feature is one-mode
only.

```text
desktop  → 1280 x 900
mobile   → 390 x 844    # iPhone 16 Pro physical width
```

For features that need additional breakpoints (tablet, narrow
desktop, ultrawide), add explicit rows to the matrix. Do not assume
a tested viewport covers an untested one.

## Driver recommendations by platform

The matrix shape is platform-agnostic. The driver is not.

| Platform              | Primary driver               | CI-tight alternative      |
|-----------------------|------------------------------|---------------------------|
| Web / PWA             | Playwright (MCP-driven)      | Playwright headless       |
| iOS native            | Maestro                      | XCUITest                  |
| Android native        | Maestro                      | Espresso                  |
| Embedded (ESP32 etc.) | pytest-embedded via HIL rig  | (no good CI alternative)  |
| CLI                   | Direct shell + expect-style  | `bats` / `expect` scripts |

Pick the driver per feature; document the choice in the spec. The
matrix shape does not change between drivers.

## Catalog discipline: reference, never duplicate

Reusable cases live in the target project's
`agents/docs/testing-knowledge.md` catalog. Per-spec matrices
REFERENCE catalog entries by stable short name; they do not paste
in the case body.

Example spec matrix row that references the catalog:

```markdown
| Empty list, fresh user (see testing-knowledge.md#empty-list-fresh-user) | desktop+mobile | no records | open list view | empty-state copy renders | no WARN / ERROR |
```

The corresponding catalog entry lives separately:

```markdown
### Case: empty-list-fresh-user

**Scenario.** A first-time user opens the list view with no records
in their account.

**Why added.** Guards against the empty-state regression where the
list rendered a skeleton loader forever instead of the empty-state
copy.

**Steps.**
1. Sign up a fresh user and authenticate.
2. Navigate to the list view URL.
3. Wait for the list container to render.

**Expected user-visible.** Empty-state copy and CTA button render
within 500ms; no skeleton flash on second render.

**Expected log trail.** One INFO `list.fetch.empty`. No WARN or
ERROR. No retry log entries.
```

The discipline:

- A case body changes? Update it once, in the catalog. Every spec
  that references it picks up the change automatically.
- A case is needed by a new spec? Add it to the catalog with the
  template above, then reference it from the spec.
- A case is used by exactly one spec and never expected to recur?
  Still add it to the catalog. The catalog is the audit trail.

## Catalog entry template

```markdown
### Case: <short-kebab-name>

**Scenario.** <one paragraph>

**Why added.** <which regression / contract this guards>

**Steps.** <numbered, driver-callable>

**Expected user-visible.** <what the user sees>

**Expected log trail.** <required + forbidden log entries>
```

Keep the name kebab-case and stable — once a spec references
`#login-bad-password`, renaming the entry breaks every reference.

## Pre-handover gate (verbatim)

Before declaring a feature done, ALL of the following must hold:

1. Every matrix row green.
2. Evidence captured per row (screenshots / log excerpts).
3. Lint clean.
4. Typecheck clean.
5. Unit tests clean.
6. Deployable artifact built.

No partial green. No "we'll fix it next sprint."

## Unreachable cases: handover format

When a case is genuinely unreachable in the chosen driver, flag it
explicitly. Never silently drop it.

Required handover section format:

```markdown
## Operator follow-up

The following matrix cases could not be exercised by the agent and
require manual verification:

- **Case: ios-safari-audio-resume** — Playwright Chromium cannot
  reproduce iOS Safari's transient-activation gesture requirement.
  Reproduction: open the feature on a real iOS device, background
  the tab for 30s, return, tap play.
- **Case: real-device-camera-permission** — agent cannot grant
  native camera permission. Reproduction: <smallest steps>.
```

Each entry: case name, why it's unreachable, smallest reproduction
the operator can run.

## Common anti-patterns

- **Mocking in e2e.** Mocks belong in unit tests. E2E against
  mocks provides no defense against integration regressions.
- **Skipping the mobile viewport "because the feature looks
  desktopy".** Layout regressions land where the agent didn't
  look.
- **Declaring done without log evidence.** A passing UI screenshot
  with WARN noise in the console is not green.
- **Reusing fixture state across cases.** Each case starts from
  its declared pre-state; reset between cases.
- **Duplicating case bodies into specs.** This is how catalog and
  spec drift apart. Reference, don't paste.
