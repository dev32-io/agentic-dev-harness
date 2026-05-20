# tests/

Structural contract enforcement for the rule-file ecosystem.

## What lives here

- `lint-rules.sh` — validates the rule-file structural contract (this phase).
- `install-test.sh` — installer smoke test (future phase).
- `fixtures/` — sample rule/doc files for installer + lint tests (future phase).

## The contract (5 checks)

`lint-rules.sh` enforces:

1. **LOC ceiling.** Every `base/rules/*.md` and `platforms/*/rules/*.md` is
   ≤100 lines.
2. **Base pairing.** Every `base/rules/<name>.md` has a paired
   `base/docs/<name>-details.md`.
3. **Platform pairing.** Every `platforms/<p>/rules/<name>.md` has a paired
   `platforms/<p>/docs/<name>-details.md`.
4. **Valid frontmatter.** Every rule file opens with `---` on line 1, contains
   a `description:` field, and closes with `---`. An optional `paths:` glob
   may follow.
5. **No language globs in base.** A `base/rules/*.md` whose frontmatter
   `paths:` line mentions any of `*.ts`, `*.tsx`, `*.kt`, `*.swift`, `*.py`,
   `*.rs`, `*.go` fails. Language-specific rules belong under `platforms/`.

## How to run

```sh
sh tests/lint-rules.sh
```

- Exit 0 on success. Prints `lint-rules.sh: OK` to stdout.
- Exit 1 on any failure. Prints one `FAIL: <message>` line per violation to
  stderr, then `lint-rules.sh: FAILED`.

The script is POSIX `sh`, uses `set -eu`, and derives its own root via
`$(cd "$(dirname "$0")/.." && pwd)` — runnable from any working directory.

When directories don't exist yet (pre-Phase-3), checks vacuously pass.

## Mobile rule contract (platforms/{android,ios,mobile}/rules/)

Rule files under the mobile platforms (`android`, `ios`, `mobile`) MUST conform
to this stricter contract on top of the base contract:

1. **Length:** ≤40 lines including YAML frontmatter (temporarily 100 during the
   May-2026 overhaul; tightens to 40 when Phase 2 lands).
2. **No fenced code blocks** (no ` ``` ` or `~~~`). Code lives in the paired
   `*-details.md` file under `platforms/<plat>/docs/`.
3. **Frontmatter `paths:` is required** (in addition to `description:`).
4. **Mobile-overlay rules** (`platforms/mobile/rules/*.md`) MUST list
   `*.kt`, `*.kts`, and `*.swift` in their `paths:` glob.

Rationale: Anthropic's documented attention budget for package rules is
30-60 lines per file; with ~10 mobile rules path-loading on a single `.kt`
edit, the budget compounds. Tighter rules + richer details files keeps the
auto-loaded payload under the adherence ceiling.

The self-test (`tests/lint-rules-self-test.sh`) verifies each check fires
correctly on fixtures under `tests/fixtures/lint-rules/`.
