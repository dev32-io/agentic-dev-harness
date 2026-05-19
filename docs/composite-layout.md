# Composite layout: base + platforms + chains

How `base/` and `platforms/*` combine into a per-project ruleset at install time.

## base/ vs platforms/

`base/` holds rules that are workflow-essential and language-agnostic: clean-code, testing discipline, git workflow, error handling, logging, collaboration, e2e testing. Every project gets these, regardless of stack.

`platforms/*` holds rules that are stack-specific: a language (`typescript`, `python`), a runtime (`node`, `bun`), a framework or product shape (`web`, `android`, `ios`), or a shared overlay across siblings (`mobile`). A platform is installed only when explicitly requested via `install.sh --platforms ...`.

The scope rule is enforced mechanically by `tests/lint-rules.sh`:

> If a rule could only ever fire on `*.ts`, `*.tsx`, `*.kt`, `*.swift`, `*.py`, `*.rs`, or `*.go` — or only inside one architectural style — it does not belong in `base/`.

The linter rejects single-language path globs (`paths: "**/*.ts"`, etc.) in `base/rules/`. If a rule wants to constrain itself to one language's files, that rule lives under `platforms/<that-platform>/` instead.

## Chain manifests

Each platform may ship a `chain.yaml` to declare how it composes with other platforms. There are two forms.

**Form 1 — `chain:`.** *This platform pulls in named overlays.* Used by stacks that always sit on top of a shared layer.

```yaml
# platforms/web/chain.yaml
chain:
  - typescript
```

Used by: `android` (chains `mobile`), `ios` (chains `mobile`), `web` (chains `typescript`), `node` (chains `typescript`), `bun` (chains `typescript`).

**Form 2 — `chained-by:`.** *This overlay is automatically included when any of the named platforms is in `--platforms`.* The inverse direction: shared overlays announce their consumers.

```yaml
# platforms/typescript/chain.yaml
chained-by:
  - web
  - node
  - bun
```

The resolver walks both directions and deduplicates. Listing `typescript` twice (once via `chain:` from `web` and once via `chained-by:` on `typescript` itself) installs it exactly once.

## paths: globs

Every rule file declares which paths it applies to via its frontmatter `paths:` field. Rules fire only when an edited file matches.

- `base/rules/clean-code.md` uses `paths: "**/*"` — applies everywhere.
- `platforms/android/rules/compose-ui.md` uses `paths: "**/*.kt"` — silent on TypeScript edits.
- `platforms/esp32/rules/freertos-tasks.md` uses `paths: "**/*.c, **/*.cpp, **/*.h"` — silent on Kotlin.

The point is noise control. A model spending its context budget on FreeRTOS rules while editing a React component is wasting that budget.

## --no-chain opt-out

`install.sh --platforms web --no-chain` installs `web` *without* the `typescript` overlay. Use this when you actually want plain JavaScript (`.js`, not `.ts`), or any other case where the default chain is wrong for your project. Rare, but documented because the chain is otherwise invisible and surprising.

## Worked example: install web + bun

```sh
./install.sh --platforms web,bun ~/code/my-app
```

Chain resolution:

1. `web` requests `typescript` via `chain:`.
2. `bun` requests `typescript` via `chain:`.
3. `typescript` accepts via `chained-by:` listing both.
4. Deduplicate: final platform list = `web`, `bun`, `typescript`.

Resulting layout in `~/code/my-app/.claude/`:

```
.claude/
├── rules/
│   ├── (all of base/rules/*.md)
│   ├── (all of platforms/web/rules/*.md)
│   ├── (all of platforms/bun/rules/*.md)
│   └── (all of platforms/typescript/rules/*.md)
└── docs/
    ├── (all of base/docs/*-details.md)
    ├── (all of platforms/web/docs/*-details.md)
    ├── (all of platforms/bun/docs/*-details.md)
    └── (all of platforms/typescript/docs/*-details.md)
```

Each rule file's `paths:` glob handles the runtime scoping; the directory layout is flat per tier.
