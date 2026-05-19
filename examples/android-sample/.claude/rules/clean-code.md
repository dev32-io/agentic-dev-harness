---
description: File/function size limits, no magic numbers, no dead code, readable names. Keeps agent context manageable.
---

# Clean Code

The harness relies on context fitting in the model's window.
Sprawling files break that. Clean code is not aesthetics — it is
how a long-running agent keeps reasoning coherent across a session.
When a rule is unclear, see `base/docs/clean-code-details.md`.

## Size limits

- Files: MUST stay under 300 lines. Split at 250.
- Functions: MUST stay under 40 lines. Extract at 30.
- Max nesting depth: 3. Use early returns to flatten.
- Split by RESPONSIBILITY, not by line count alone. The line limit
  is the smoke alarm; the cause is usually two concepts fused into
  one file.

## One concept per file

- If a file's name needs an "and" to describe it, it does two
  things — split. `audio-pipeline.md` good.
  `audio-and-presence-and-fallback.md` not.
- If you cannot name the file's purpose in three words, split it.
- One exported concept per file by default. Helpers that exist
  ONLY to serve that concept live in the same file. Helpers used
  by multiple concepts move to their own file.

## No magic numbers

- Every numeric literal that is not `0`, `1`, or `-1` MUST be a
  named constant. `3600` is a riddle; `SECONDS_PER_HOUR` is a
  statement.
- Apply the same rule to magic strings used as protocol tokens,
  state names, or routing keys. Constants are typo-proof; string
  literals scattered across files are not.

## No dead code in commits

- No commented-out blocks. Git is the history.
- No leftover debug stubs (`console.log`, `print`, debugger).
- No `// TODO: figure this out` placeholders without an owner and
  a ticket reference. A TODO without a deadline is a wish.
- No unused imports, variables, or parameters.

Strip before commit. Dead code costs context tokens and lies to
readers about what is in use.

## Long prompts and templates live in `.md` files

- System prompts, persona docs, agent instructions, and other long
  template strings MUST live in dedicated `*.md` files loaded at
  runtime.
- They MUST NOT be inlined as multi-hundred-line string literals
  in source files.
- This keeps source files focused on logic, makes prompt content
  reviewable as text, and lets operators swap content without a
  code rebuild.

## Readable names

- Variables and function names read like sentences in context.
- Booleans as questions: `isReady`, `hasError`, `canTransition`,
  `shouldRetry`. Not `ready`, `error`, `transition`, `retry`.
- Functions as actions: `createSession`, `validateToken`,
  `parseFrame`. The verb is mandatory.
- AVOID `data`, `info`, `manager`, `handler`, `util`, `helper`,
  `service` as bare names. They describe everything and nothing.
  Be specific: `pendingMessages`, `sessionRecord`, `tokenValidator`.

## Pure functions where you can

- Prefer pure functions. No side effects, same input → same output.
- Return new objects for state changes. Do not mutate parameters.
- A pure function is testable, parallelizable, and reasoning-safe.
  An impure one is a small wager about the order of execution.

## Why this discipline matters

A long-running agent rereads files as it works. Every file over
the size limit, every magic number, every dead block, every
`data` named variable, costs tokens AND injects ambiguity. The
discipline below is what keeps the agent's reasoning intact across
a multi-hour session.
