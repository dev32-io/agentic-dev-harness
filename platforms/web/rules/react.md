---
description: React -- function components, hooks discipline, no useEffect for derived state.
paths: "**/*.tsx,**/*.jsx"
---

# React

React's modern API has a strong opinion: function components,
hooks, and derived values computed in render. Code that fights
that opinion produces the bugs the framework cannot help you
catch. When a rule is unclear, see
`platforms/web/docs/react-details.md`.

## Function components only

- No class components. The class API is legacy; new code uses
  functions and hooks.
- Hooks are the unit of stateful logic. Custom hooks compose
  cleanly; class lifecycle methods do not.
- If you reach for a class because "I need lifecycle methods" --
  the answer is `useEffect` for I/O side effects, and the
  render function itself for everything else.

## Hooks discipline -- the rules of hooks are non-negotiable

- Call hooks at the top level of a component or another hook.
  NEVER inside conditionals, loops, or after early returns.
- The compiler / linter (`react-hooks/rules-of-hooks`) MUST be
  enabled and treated as an error, not a warning. Hook-rule
  violations corrupt component state silently.
- The dependency arrays for `useEffect` / `useMemo` / `useCallback`
  are checked by `react-hooks/exhaustive-deps`. Disabling that
  rule on a line MUST come with a written reason in a comment.

## No `useEffect` for derived state -- use `useMemo`

- If a value can be computed from props + state during render,
  compute it during render. Do NOT `useState` + `useEffect` to
  mirror it.
- `useMemo` is for memoizing the COMPUTATION when the inputs are
  stable; it is not for "saving" a value into state.
- `useEffect` is for synchronizing with an EXTERNAL system
  (network, DOM, subscriptions, timers). If there is no external
  system, there is no effect.

## Keys on lists are stable identifiers, not array indices

- The `key` prop is React's reconciliation contract. Stable IDs
  (`item.id`) are correct; array indices are correct ONLY for
  static, never-reordered lists.
- Index-as-key on a reorderable list silently corrupts component
  state (focus, scroll, animation, uncontrolled inputs).

## Server Components when applicable

- In a framework with React Server Components (RSC) -- e.g.
  Next.js App Router -- prefer Server Components for data
  fetching and non-interactive rendering. Client Components are
  for interactivity.
- `"use client"` is opt-in and marks a real boundary. Avoid
  unnecessary client islands; they ship JS to every visitor.

## Forbidden patterns

- Mutating state directly (`state.x = y`). State is immutable;
  produce a new value.
- Calling a setter from render unconditionally -- causes an
  infinite render loop. Setters belong in event handlers or
  effects.
- `useEffect(() => setX(deriveFromProps(p)), [p])` -- the textbook
  derived-state-via-effect anti-pattern. Compute it in render.

## Why this discipline matters

The hook rules and render-purity rules are what let React's
optimizer (memoization, concurrent rendering, Server Components)
work correctly. Breaking them gives the framework no way to
help you; the resulting bugs look like "it works in dev,
flickers in prod" and resist debugging.
