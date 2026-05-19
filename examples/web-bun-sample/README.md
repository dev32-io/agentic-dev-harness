# examples/web-bun-sample

Minimal Bun project pre-wired with the agentic-dev-harness rule + hook system.

## How it was set up

1. `bun init -y -m` (minimal)
2. Hand-edited `package.json` to add the harness-expected scripts (`lint`, `typecheck`, `test`, `test:unit`, `start`) and `engines.bun >= 1.2`.
3. Added `src/index.ts` (single-route `Bun.serve`) and `src/index.test.ts` (one passing `bun:test` smoke test).
4. From the harness repo root: `sh install.sh --target examples/web-bun-sample --platforms web,bun`.
5. Chain resolution pulled in `typescript` automatically (via `platforms/bun/chain.yaml` / `platforms/web/chain.yaml`).
6. Quality gate ran green:

   ```
   $ sh scripts/quality-gate.sh all
   $ echo 'lint stub'
   lint stub
   $ tsc --noEmit
   $ bun test
   bun test v1.3.11 (af24e281)

    1 pass
    0 fail
    1 expect() calls
   Ran 1 test across 1 file.
   ```

## To run locally

Requires Bun 1.2+.

```
bun install
sh scripts/quality-gate.sh all
```

To start the server:

```
bun run start
# → Listening on http://localhost:3000
```

## What got installed

- `.claude/rules/` — base 7 rules (top level) plus `web/`, `bun/`, `typescript/` overlays (chained via `platforms/{web,bun}/chain.yaml`).
- `agents/docs/` — paired `*-details.md` for each rule, plus seeded `learnings.md` and `testing-knowledge.md`.
- `CLAUDE.md` — meta-gate from `CLAUDE.md.template` (rename project + fill in architecture before using).
- `scripts/quality-gate.sh` — platform-aware (auto-detects Bun via `package.json` + `bun.lock`).
- `.claude/settings.json` — two-hook CI pair (`PostToolUse` + `TaskCompleted`).
