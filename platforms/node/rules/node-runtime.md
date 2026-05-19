---
description: Node runtime -- supported LTS only, engines pin, no --experimental-* in production.
paths: "**/*.ts,**/*.js"
---

# Node Runtime

The Node version is a runtime contract, not an implementation
detail. Code that depends on an unsupported version is a
maintenance liability the moment the LTS line ends. When a
rule is unclear, see
`platforms/node/docs/node-runtime-details.md`.

## Target a SUPPORTED LTS line

- New projects target the current active LTS (e.g. Node 22 as of
  this writing). Existing projects stay within an LTS window;
  the upgrade path from one LTS to the next is a planned task,
  not a "we'll get to it."
- Odd-numbered (non-LTS) Node releases are NOT production
  targets. They are fine for experimentation; they are not what
  you ship.
- End-of-life Node lines are an explicit security risk -- the
  team owns either an upgrade or a stated, time-bounded
  exception.

## Pin the version via `engines` in `package.json`

```json
{
    "engines": {
        "node": ">=22.0.0 <23.0.0"
    }
}
```

- `engines` is read by `npm`, `pnpm`, `bun`, and most CI setups.
  Combined with `engineStrict: true` (or `engine-strict=true`
  in `.npmrc`), version drift fails fast at install time.
- The CI matrix runs at LEAST the pinned major; production
  containers run a fixed minor (e.g. `node:22.10-bookworm`).
- A `.nvmrc` (or `.tool-versions`) at the repo root carries the
  same version for local developer machines.

## `--experimental-*` flags are FORBIDDEN in production

- Flags like `--experimental-vm-modules`, `--experimental-fetch`
  (in older Node), `--experimental-loader` change semantics
  between minor releases. Production code that requires them is
  one Node bump away from breakage.
- Scratch scripts, prototypes, and local exploration may use
  experimental flags freely. The production entry point may not.
- If a feature genuinely requires an experimental flag, the team
  records that choice with an issue link and a tracked removal
  date.

## Module system -- one choice, written down

- ESM (`"type": "module"`) is the default for new projects.
  CommonJS remains valid; mixing the two within one package is
  the failure mode.
- The choice is in `package.json` (`"type"`), and the build
  config (TypeScript `module` / `moduleResolution`) matches.
- Dynamic `require()` from ESM and dynamic `import()` from CJS
  are escape hatches, not patterns.

## Standard library over micro-deps

- `node:fs/promises`, `node:path`, `node:crypto`,
  `node:test`, `node:fetch` (Node 18+), `AbortController` cover
  most of what tiny npm packages used to provide.
- A new transitive dependency is a supply-chain risk. The bar
  for adding one is "the standard library can't do this OR the
  dep is well-maintained and load-bearing."

## Why this discipline matters

Node's release cadence is fast; an unpinned project drifts off
LTS in months. `engines` + a fixed container image + an
explicit module choice make the runtime a deliberate property
of the codebase, not an emergent one from "whatever the laptop
had installed."
