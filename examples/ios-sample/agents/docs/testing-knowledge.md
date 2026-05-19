# Testing Knowledge

> Reusable case catalog referenced by `.claude/rules/e2e-testing.md` and `agents/docs/e2e-testing-details.md`.

## The contract

**Cases live here. Specs reference cases by name. NEVER duplicate case bodies into specs.**

Example matrix row syntax:

```
| Case: First-time login (see testing-knowledge.md#first-time-login) | desktop+mobile | … |
```

## Why this rule exists

A case defined in 4 specs ends up with 4 slightly different step lists after 4 refactors. The catalog is the single source of truth. When the case changes, you change it once.

## Methods

One subsection per surface. Each subsection states the driver (Playwright, Maestro, XCUITest, pytest-embedded, etc.) and why it was chosen for that surface.

<!-- Project owners: add Methods subsections here as you onboard surfaces. -->

## Cases

```markdown
### Case: <short-kebab-case-name>

**Scenario:** <one-sentence user-level description>

**Why added:** <regression guard / contract guard / new behavior>

**Steps:**
1.
2.
3.

**Expected user-visible:**
**Expected log trail:**
```

<!-- New cases appended here. Reference them from spec matrices by anchor (#case-name). -->
