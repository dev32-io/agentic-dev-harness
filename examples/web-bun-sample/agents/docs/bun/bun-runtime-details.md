# Bun Runtime -- Details & Examples

This file expands `platforms/bun/rules/bun-runtime.md`.

## Pin set -- the four sources that must agree

```json
// package.json
{
    "name": "@example/service",
    "type": "module",
    "engines": {
        "bun": ">=1.2.0 <2.0.0"
    },
    "scripts": {
        "dev":      "bun run --hot src/main.ts",
        "start":    "bun run src/main.ts",
        "test":     "bun test",
        "build":    "bun build src/main.ts --outdir dist --target bun",
        "lint":     "biome lint .",
        "typecheck":"tsc --noEmit"
    }
}
```

```toml
# bunfig.toml -- optional, but if present it owns runtime config.
[install]
exact = true                # save dependencies as exact versions
auto = "fallback"           # only auto-install if not in package.json

[test]
preload = ["./tests/setup.ts"]
```

```text
# .tool-versions (or .mise.toml)
bun 1.2.0
```

```dockerfile
# Dockerfile
FROM oven/bun:1.2 AS build
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun build src/main.ts --outdir dist --target bun

FROM oven/bun:1.2-slim AS runtime
WORKDIR /app
COPY --from=build /app/dist /app/dist
USER bun
CMD ["bun", "run", "dist/main.js"]
```

All four sources reference the same Bun 1.2 line. Drift between
them is the cause of "works on my laptop, breaks in the
container."

## `Bun.serve` -- the canonical HTTP server

```ts
// src/main.ts
import { handleGetHealth, handleGetUser } from "./routes";

const server = Bun.serve({
    port: Number(process.env.PORT ?? 3000),
    routes: {
        "/health":         handleGetHealth,
        "/users/:id":      handleGetUser,
    },
    fetch(req) {
        return new Response("Not Found", { status: 404 });
    },
    error(err) {
        console.error(err);
        return new Response("Internal Server Error", { status: 500 });
    },
});

console.log(`listening on http://localhost:${server.port}`);
```

```ts
// src/routes.ts
import type { BunRequest } from "bun";

export function handleGetHealth(_req: BunRequest): Response {
    return new Response(JSON.stringify({ ok: true }), {
        headers: { "content-type": "application/json" },
    });
}

export async function handleGetUser(
    req: BunRequest<"/users/:id">,
): Promise<Response> {
    const { id } = req.params;
    const user = await loadUser(id);
    if (!user) return new Response("Not Found", { status: 404 });
    return Response.json(user);
}
```

The handler is a function from a `Request` to a `Response`. It
ports to Cloudflare Workers, Deno, or any other Fetch-shape
runtime without rewriting; switching off Bun later is a config
change, not an architecture change.

## `Bun.file` and `Bun.write`

```ts
// Read.
const config = await Bun.file("./config.json").json();
const text   = await Bun.file("./README.md").text();
const bytes  = await Bun.file("./logo.png").bytes();

// Write.
await Bun.write("./out/result.json", JSON.stringify(data));

// Stream a file to a Response.
return new Response(Bun.file("./public/large.bin"));

// Compare: the Node-compat path requires multiple imports and
// manual stream wiring. Bun.file is one line and zero overhead.
```

## `Bun.spawn` -- subprocesses

```ts
const proc = Bun.spawn(["git", "rev-parse", "HEAD"], {
    stdout: "pipe",
});
const sha = (await new Response(proc.stdout).text()).trim();
await proc.exited;   // wait, propagate non-zero exit if any
```

`child_process.spawn` works, but `Bun.spawn` is faster, the API
is smaller, and `proc.stdout` is a `ReadableStream` -- the same
shape as a Fetch body, which composes naturally.

## `bun:sqlite` for embedded data

```ts
import { Database } from "bun:sqlite";

const db = new Database("./app.db", { create: true });
db.run(`
    CREATE TABLE IF NOT EXISTS users (
        id   TEXT PRIMARY KEY,
        name TEXT NOT NULL
    )
`);

const upsert = db.prepare(`
    INSERT INTO users (id, name) VALUES (?, ?)
    ON CONFLICT (id) DO UPDATE SET name = excluded.name
`);
upsert.run("u1", "Alice");

const row = db.query("SELECT name FROM users WHERE id = ?")
    .get("u1") as { name: string } | null;
```

Built-in, fast, no native build step. Compare with the
`better-sqlite3` install dance.

## `Bun.password` for password hashing

```ts
// Hash on registration.
const hash = await Bun.password.hash(plaintext);   // argon2id by default
await db.users.insert({ email, hash });

// Verify on login.
const ok = await Bun.password.verify(plaintext, user.hash);
```

Defaults to argon2id with sensible parameters. No `npm install
argon2`, no native build to maintain.

## Lockfile -- modern text format

```text
$ bun install
$ ls
bun.lock          # text, diffable in PRs
node_modules/
```

For an existing project on `bun.lockb` (binary):

```text
$ bun install --save-text-lockfile
$ git rm bun.lockb
$ git add bun.lock
$ git commit -m "build: migrate bun lockfile to text format"
```

One commit, then code review can actually review the lockfile.

## Top-level await

```ts
// src/main.ts -- no IIFE needed.
import { loadConfig } from "./config";

const config = await loadConfig();
const server = Bun.serve({
    port: config.port,
    fetch: makeFetchHandler(config),
});
```

The Node-CJS-era IIFE pattern (`(async () => { ... })()`) is
unnecessary -- and a missing top-level `await` is the kind of
thing the type system can't help you with.

(PRs welcome to deepen this platform.)
