# Node Runtime -- Details & Examples

This file expands `platforms/node/rules/node-runtime.md`.

## The full `package.json` pin

```json
{
    "name": "@example/server",
    "version": "1.0.0",
    "type": "module",
    "engines": {
        "node": ">=22.0.0 <23.0.0",
        "npm":  ">=10.0.0"
    },
    "scripts": {
        "lint":       "eslint .",
        "typecheck":  "tsc --noEmit",
        "test":       "node --test",
        "build":      "tsc -p tsconfig.build.json",
        "start":      "node ./dist/main.js"
    }
}
```

Adjacent files:

```
.nvmrc              -> 22
.tool-versions      -> nodejs 22.10.0
.npmrc              -> engine-strict=true
Dockerfile          -> FROM node:22.10-bookworm
```

The four sources agree. Drift between them is the cause of "it
works on my machine" -- explicit pinning closes that gap.

## Why `engineStrict` matters

Without it:

```text
$ npm install   # on Node 18, package requires 22
npm warn engine ... # warning, install proceeds
```

With `engine-strict=true` in `.npmrc`:

```text
$ npm install
npm ERR! engine Unsupported engine
npm ERR! engine required: node ">=22.0.0 <23.0.0"
npm ERR! engine current:  node 18.20.0
```

The CI build fails on install, before any test runs. That is the
behavior you want.

## The experimental-flag trap

```text
# Production startup -- FORBIDDEN.
node --experimental-vm-modules --experimental-loader ./loader.js dist/main.js
```

Problems:
- Semantics may change in any minor Node release.
- New maintainers won't know which flag did what.
- The flag set is invisible to the type system and the test
  suite.

If a feature legitimately requires an experimental flag, the
team records the decision:

```text
docs/decisions/0007-experimental-vm-modules.md
  Status: ACCEPTED
  Date:   2025-01-15
  Reason: vitest workerThreads-mode needs vm modules until v3.
  Removal: When vitest 3.x ships; tracked at issue #142.
  Owner:  @platform-team
```

The decision has an owner, a removal trigger, and is searchable.

## ESM vs CommonJS -- pick one and commit

```json
// ESM project.
{
    "type": "module",
    "main": "./dist/main.js",
    "exports": {
        ".":         "./dist/main.js",
        "./client":  "./dist/client.js"
    }
}
```

```ts
// In ESM-land:
import { readFile } from "node:fs/promises";
import { router } from "./router.js";   // note: explicit .js extension

const dynamic = await import("./feature.js");
```

```json
// CommonJS project.
{
    "main": "./dist/main.js"
}
```

```ts
// In CJS-land:
const { readFile } = require("node:fs/promises");
const { router } = require("./router");

(async () => {
    const dynamic = await import("./feature.js");   // dynamic import is async
})();
```

The two interop, but mixing within one package is where
"`require() of ES Module` not supported" errors live.
TypeScript's `module: "NodeNext"` + `moduleResolution: "NodeNext"`
will catch most of these at compile time.

## Standard library wins to remember

```ts
// File I/O -- no `fs-extra` for the simple cases.
import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
await mkdir("./out", { recursive: true });
await writeFile("./out/result.json", JSON.stringify(data));

// HTTP client -- the built-in fetch is fine for most use.
const res = await fetch("https://api.example.com/products", {
    signal: AbortSignal.timeout(5_000),
});

// Test runner -- node's built-in is enough for plain unit tests.
import { test } from "node:test";
import assert from "node:assert/strict";

test("adds two numbers", () => {
    assert.equal(2 + 2, 4);
});

// Crypto -- UUIDs, hashes, random.
import { randomUUID, createHash } from "node:crypto";
const id = randomUUID();
const sha = createHash("sha256").update(input).digest("hex");
```

A new transitive dep that wraps `node:crypto` adds maintenance
cost the team will own for the project's lifetime.

## Containers and the actual runtime

`Dockerfile`:

```dockerfile
FROM node:22.10-bookworm AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=optional
COPY . .
RUN npm run build

FROM node:22.10-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist         ./dist
COPY --from=build /app/package.json ./
USER node
CMD ["node", "./dist/main.js"]
```

Note: the runtime stage uses the SAME Node minor as build. A
mismatch ("build on 22.10, run on 22.9") is a real source of
subtle binary-add-on incompatibility.

## When the LTS line ends

LTS lines end on a published schedule. The team's calendar tracks
the EOL date for the current pin; the upgrade work is scheduled
in advance, not discovered at EOL+1 week.

(PRs welcome to deepen this platform.)
