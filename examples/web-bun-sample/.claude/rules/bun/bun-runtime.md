---
description: Bun runtime -- version pinned, lockfile committed, native Bun APIs preferred.
paths: "**/*.ts,**/*.js"
---

# Bun Runtime

Bun is a JavaScript/TypeScript runtime AND package manager AND
test runner AND bundler in one binary. Using it as a strict
Node replacement gives up most of the leverage. When a rule is
unclear, see `platforms/bun/docs/bun-runtime-details.md`.

## Pin the Bun version in `package.json`

```json
{
    "engines": {
        "bun": ">=1.2.0"
    }
}
```

- Bun's API surface is still evolving release to release; an
  unpinned project drifts.
- `bunfig.toml` may also pin or constrain the runtime; if the
  team uses it, the version there agrees with `engines.bun`.
- A `.tool-versions` (or `.mise.toml`) at the repo root pins the
  same version for local developer machines.

## Commit the lockfile

- Bun produces `bun.lock` (the modern text format, since Bun
  1.2) or `bun.lockb` (the older binary format). EXACTLY ONE
  of these is checked in.
- New projects use `bun.lock` -- diffable in code review, easier
  to merge.
- Existing projects on `bun.lockb` MAY migrate (`bun install
  --save-text-lockfile`); the migration is one commit, not a
  drawn-out flag-flip.

## Prefer `Bun.serve()` over Express for HTTP

```ts
const server = Bun.serve({
    port: 3000,
    fetch(req) {
        const url = new URL(req.url);
        if (url.pathname === "/health") return new Response("ok");
        return new Response("Not Found", { status: 404 });
    },
});
```

- `Bun.serve` is built in. No `npm install express`. No
  middleware-stack mystery meat.
- The handler is a function from `Request` to `Response` --
  the same shape as a Fetch handler, which is the shape of
  every modern edge runtime (Cloudflare Workers, Deno, Vercel
  Edge).
- For routing, prefer a small router built on the same `Request`
  / `Response` shape (e.g. `Bun.serve`'s built-in `routes`
  table, or Hono) over the legacy Express middleware model.

## Prefer Bun-native APIs over Node-compat shims

| Bun-native        | Node compat (works, but not the point)         |
| ----------------- | ---------------------------------------------- |
| `Bun.file(path)`  | `fs.readFile(path)`                            |
| `Bun.write(...)`  | `fs.writeFile(...)`                            |
| `Bun.spawn(...)`  | `child_process.spawn(...)`                     |
| `Bun.password`    | hand-rolled argon2/bcrypt with a dep           |
| `bun:sqlite`      | `better-sqlite3` (npm)                         |
| `bun:test`        | `jest` / `vitest` (npm)                        |

- Bun-native APIs are faster and have fewer surprises.
- Falling back to Node-compat is fine in code that may run on
  Node too (a shared library). In a Bun-only service, prefer
  the native form.

## Top-level await and ESM by default

- Bun assumes ESM. `"type": "module"` in `package.json` (Bun
  may infer it; making it explicit is friendlier to other
  tooling).
- Top-level `await` is supported; use it instead of an IIFE in
  entry-point scripts.

## Why this discipline matters

A project that uses Bun as "Node, but faster" is a project that
gets Node's surface area plus Bun's instability. A project that
adopts the Bun-native shape (`Bun.serve`, `Bun.file`,
`bun:sqlite`, `bun:test`) gets the leverage Bun was built to
provide and a smaller dependency tree as a side effect.
