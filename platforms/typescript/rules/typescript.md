---
paths: "**/*.ts,**/*.tsx"
description: TypeScript strict mode, no any, immutable-by-default, type-only imports.
---

# TypeScript

TypeScript without strict mode is JavaScript with extra ceremony.
The whole point is to push errors from runtime to compile time so
a long-running agent doesn't ship surprises. When a rule is
unclear, see `platforms/typescript/docs/typescript-details.md`.

## Strict mode (non-negotiable)

- `tsconfig.json` MUST set `strict: true`.
- `noUncheckedIndexedAccess: true` — `arr[0]` is `T | undefined`,
  not `T`. Forces the agent to handle the empty case.
- `exactOptionalPropertyTypes: true` — `{ x?: number }` does NOT
  accept `{ x: undefined }`. Distinguishes "absent" from "present
  but undefined".
- `noImplicitOverride: true` — subclass methods that override MUST
  use the `override` keyword.

## No `any`

- `any` opts out of type-checking and infects every value it
  touches. Use `unknown` for unvalidated input and narrow with
  type guards or schema validation.
- ESLint MUST set `@typescript-eslint/no-explicit-any: "error"`.
- `as unknown as Foo` double-casts are also forbidden; if you
  need to assert a shape, write a guard.

## Explicit error types

- Never `throw "some string"`. Strings carry no stack.
- Never `throw new Error("message")` at a boundary that callers
  need to discriminate. Define an error class or a discriminated
  union.
- Functions that can fail in a known way return `Result<T, E>`
  instead of throwing. Throwing is for bugs; `Result` is for
  expected failure modes (network down, parse failed, not found).
- Public boundary signatures MUST declare the error type. A caller
  reading the type alone should know what can go wrong.

## Immutable by default

- Object properties declared with `readonly` unless mutation is
  the point. Class fields default to `readonly`.
- Arrays passed across boundaries typed as `ReadonlyArray<T>`.
- Function parameters typed as `Readonly<T>` when the function
  must not mutate them.
- Local mutation inside a function is fine. Mutation of inputs is
  not.

## Type-only imports

- `import type { Foo } from "./foo"` for anything used only in
  type positions. Keeps the runtime import graph minimal and
  helps tree-shaking.
- ESLint MUST set `@typescript-eslint/consistent-type-imports`.

## `type` over `interface`

- Default to `type` aliases. They compose with unions,
  intersections, and mapped types.
- Use `interface` ONLY when you need declaration merging (e.g.,
  augmenting a library's types). That's the one case `type`
  cannot do.

## Why this discipline matters

A long-running agent reads types as load-bearing documentation.
`any` erases that documentation. A `throw` of an unknown shape
forces the next agent to read the implementation to learn what
can fail. Strict mode + explicit error types + immutability mean
the agent can trust the signatures and skip re-reading the body.
