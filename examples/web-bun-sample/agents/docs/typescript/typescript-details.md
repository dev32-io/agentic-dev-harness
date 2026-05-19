# TypeScript — Details & Examples

This file expands `platforms/typescript/rules/typescript.md`. The
rule defines the bar; this doc shows the full `tsconfig.json`
template, error-class and Result-type patterns, and the gotchas
around `ReadonlyArray<T>` that catch agents off-guard.

## `tsconfig.json` template

The minimum strict configuration. Every flag below is load-bearing
— removing one weakens the whole.

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],

    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "noPropertyAccessFromIndexSignature": true,

    "verbatimModuleSyntax": true,
    "isolatedModules": true,
    "forceConsistentCasingInFileNames": true,

    "esModuleInterop": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,

    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

`strict: true` is a bundle of seven flags. The four called out
in the rule (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`,
`noImplicitOverride`, plus the implicit `noImplicitAny`) are the
ones agents most often regress on, so they appear explicitly.

`verbatimModuleSyntax` enforces the type-only import discipline:
`import type` is a compile error if you actually use the binding
at runtime, and a regular `import` is a compile error if you use
the binding only as a type. No ambiguity.

## Error-class pattern

For errors a caller needs to discriminate by shape (HTTP status,
parse failure mode, validation field), define a class.

```typescript
// errors.ts
export class HTTPError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
    this.name = "HTTPError";
  }
}

export class ParseError extends Error {
  constructor(
    public readonly field: string,
    public readonly raw: string,
  ) {
    super(`parse failed at field "${field}"`);
    this.name = "ParseError";
  }
}

// caller.ts
try {
  await fetchUser(id);
} catch (e) {
  if (e instanceof HTTPError && e.status === 404) {
    return null;
  }
  throw e; // unknown — rethrow
}
```

Naming the class explicitly (`this.name = "HTTPError"`) is what
makes `console.error(e)` and JSON serialization useful in logs.

## Result type implementation

For functions whose failure modes are expected paths, return a
`Result` instead of throwing. The type forces the caller to
handle both branches at compile time.

```typescript
// result.ts
export type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export const ok = <T>(value: T): Result<T, never> => ({
  ok: true,
  value,
});

export const err = <E>(error: E): Result<never, E> => ({
  ok: false,
  error,
});

// usage
export type AppError =
  | { kind: "not-found"; id: string }
  | { kind: "network"; cause: HTTPError }
  | { kind: "parse"; cause: ParseError };

async function loadUser(id: string): Promise<Result<User, AppError>> {
  const res = await fetch(`/users/${id}`);
  if (res.status === 404) return err({ kind: "not-found", id });
  if (!res.ok) {
    return err({
      kind: "network",
      cause: new HTTPError(res.status, res.statusText),
    });
  }
  const raw = await res.text();
  const parsed = parseUser(raw);
  if (!parsed.ok) return err({ kind: "parse", cause: parsed.error });
  return ok(parsed.value);
}

// caller — discriminated union forces handling every branch
const result = await loadUser(id);
if (!result.ok) {
  switch (result.error.kind) {
    case "not-found": return renderEmpty();
    case "network": return renderRetry(result.error.cause);
    case "parse": return renderBugReport(result.error.cause);
  }
}
return renderUser(result.value);
```

The discriminant (`kind`) is what lets the compiler narrow inside
the switch. Without it, the union collapses to `AppError` and you
lose exhaustiveness.

## Immutable-array gotchas

`ReadonlyArray<T>` is structurally identical to `T[]` at runtime
but the compile-time API is restricted. This trips up agents that
expect "readonly" to mean "frozen at runtime".

### Mutation methods are compile errors

```typescript
function process(items: ReadonlyArray<number>): number {
  items.push(0);    // ERROR: Property 'push' does not exist
  items.sort();     // ERROR: Property 'sort' does not exist
  items[0] = 99;    // ERROR: Index signature is readonly
  return items[0] ?? 0;
}
```

`push`, `pop`, `shift`, `unshift`, `splice`, `sort`, `reverse`,
`fill`, and `copyWithin` are gone. Element assignment is gone.
Length assignment is gone.

### `.map` / `.filter` / `.slice` return mutable arrays

```typescript
function double(items: ReadonlyArray<number>): ReadonlyArray<number> {
  const doubled = items.map((n) => n * 2);
  // doubled is inferred as number[], not ReadonlyArray<number>
  doubled.push(0); // compiles, but caller's contract is readonly
  return doubled;  // OK — number[] widens to ReadonlyArray<number>
}
```

`Array.prototype.map` is typed as returning `T[]`. If you want the
local variable to also be readonly, annotate the return type
explicitly or cast: `const doubled: ReadonlyArray<number> = items.map(...)`.

### Sorted copy without mutation

```typescript
// BAD — mutates caller's array
function sorted(items: ReadonlyArray<number>): ReadonlyArray<number> {
  return (items as number[]).sort();
}

// GOOD — copy first, then sort the copy
function sorted(items: ReadonlyArray<number>): ReadonlyArray<number> {
  return [...items].sort((a, b) => a - b);
}
```

The cast trick compiles but at runtime mutates the original array,
because `ReadonlyArray<T>` IS `T[]` at runtime. Copy first.

## Type-only imports — when it matters

```typescript
// good — type-only, erased at build
import type { User } from "./types";

function render(u: User): string { return u.name; }

// good — runtime import (the function is called)
import { parseUser } from "./parser";

// bad — mixed, requires verbatimModuleSyntax to be off
import { parseUser, type User } from "./parser";
```

With `verbatimModuleSyntax: true`, the inline `type` modifier is
how you split runtime and type imports from the same module. The
build emits the runtime import alone; the type import is erased.

## `type` vs `interface`

```typescript
// type — unions, intersections, mapped types
type Status = "ready" | "loading" | "error";
type WithId<T> = T & { id: string };
type Readonly<T> = { readonly [K in keyof T]: T[K] };

// interface — only when declaration merging is the point
declare global {
  interface Window {
    __MY_APP__: { version: string };
  }
}
```

If a colleague says "always use interface for object shapes" —
the only reason that was idiomatic was historical (older
TypeScript optimized interfaces better). It is no longer true.
`type` wins on composition; `interface` wins only on merging.

## Why these patterns matter

`any` is a contract erasure. `throw "message"` is a contract gap.
A mutable array passed across a boundary is an invisible coupling.
Each of these silently shifts the cost of understanding the code
from the writer to the next agent. Strict mode and the patterns
above push that cost back to compile time, where it belongs.
