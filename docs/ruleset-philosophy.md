# Ruleset philosophy

Why every rule in this harness is short, imperative, atomic, path-scoped, and paired with a details file.

## Why ≤100 LOC per rule

Rules are read in their entirety by the model. They are not chunked, summarised, or lazily streamed. A 500-LOC rule blows the context budget; a 50-LOC rule pays for itself many times a session. The hard cap forces the author to split a sprawling rule into smaller ones, which usually reveals that the original was actually two or three concerns wearing one filename. The discipline is the point.

## Why instruction-only

Rules are imperatives: "MUST do X, MUST NOT do Y." They do not explain *why* and they do not give long examples. Explanation, examples, edge cases, and gotchas live in the paired `*-details.md`. Mixing the two dilutes both: the rule becomes too long to scan, and the reasoning becomes too short to actually help when an edge case hits. Keep them apart.

## Why atomic

One concern per file. `logging.md` is about logging — not about logging *and* error handling *and* telemetry. The reason is mechanical: promotion (from T3 → T2 → T1) and demotion (deprecate a rule, replace with another) become single-file operations. A "general best practices" rule file is unmaintainable: nobody knows which line is still current, and nothing can be removed without arguing about ten other things.

## Why paths: globs

A rule fires only when an edited file matches its `paths:` frontmatter. Mobile rules stay silent on a `.py` edit. ESP32 rules stay silent on a `.tsx` edit. The point is noise control: every rule that fires costs context budget, and budget spent on irrelevant rules is budget unavailable for the actual task. Path scoping is what lets the harness ship many platforms without each one paying for the others.

## Why paired details

The rule is the LAW. The details file is the CASE LAW. Lawyers — meaning engineers and the agent — read both. The rule alone is sometimes ambiguous in edge cases; the details file is where the worked examples, the historical gotchas, the "we tried this and it broke" notes live. A rule without paired details ages poorly: the reasoning fades, and the next person reads the imperative without knowing why.

The pairing is enforced by `tests/lint-rules.sh`: every `rules/foo.md` MUST have a `docs/foo-details.md` sibling, or the lint fails.

## The single-language-glob auto-detector

`tests/lint-rules.sh` rejects `paths:` values that restrict a `base/rules/*.md` file to a single language extension — `*.ts`, `*.tsx`, `*.kt`, `*.swift`, `*.py`, `*.rs`, `*.go`. The reasoning is the scope rule: if a rule should only fire on one language's files, it is not universal, and it does not belong in `base/`. It belongs under `platforms/<that-language's-platform>/`.

This rule has caught real drift during development of the harness itself. Without it, "useful rule, let's put it in base" gradually pollutes the always-loaded slice with rules that only matter to one stack. The auto-detector is small (about 20 lines of `awk` and `grep`) and runs on every CI build.

If you find yourself writing a rule that needs a single-language glob, ask: should this be a new platform? Or does it belong inside an existing one? The answer is rarely "let's bend the base/ scope rule."
