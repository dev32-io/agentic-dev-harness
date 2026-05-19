---
paths: "**/*.ts,**/*.tsx"
description: AsyncGenerator pipelines, AbortSignal respect, stream-by-default for streaming data.
---

# Decorator-Pattern Pipelines

Whenever a stream of typed items needs sequential transformation
— LLM tokens, log lines, audio frames, websocket messages, SSE
events — model the pipeline as a chain of async-generator
decorators. The shape is always linear: each stage takes an
`AsyncIterable<TIn>` and returns an `AsyncIterable<TOut>`. When a
rule is unclear, see `platforms/typescript/docs/decorator-pattern-details.md`.

## Stages are pure async generators

- Signature: `async function*(input: AsyncIterable<TIn>, signal: AbortSignal): AsyncGenerator<TOut>`.
- No mutable state shared across stages. Each stage's internal
  buffer is its own business.
- Each stage MUST be unit-testable against a fixture iterable. If
  you cannot feed it `[chunk1, chunk2, chunk3]` and assert outputs,
  the stage has hidden coupling.
- One responsibility per stage. One file per stage.

## Respect `AbortSignal` at every yield boundary

- Check `signal.aborted` before consuming the next input AND
  before yielding the next output.
- On abort: `return` cleanly. NEVER `throw`. NEVER swallow.
- Aborts propagate through the chain by design — when a consumer
  stops iterating, the `for await` in every upstream stage exits,
  releasing resources without ceremony.
- Never start work that survives the signal — every `await` that
  takes time MUST be cancellable by the same signal.

## Stream by default

- If data is sequential, prefer streaming over collect-then-process.
- Collecting into an array kills the latency benefit of streaming
  and explodes memory on long runs.
- Only buffer when the stage's logic specifically requires full
  context (e.g., reordering, deduplication across the whole stream,
  formatting that needs the final token).
- A buffering stage MUST still be a generator from the outside —
  the pipeline never knows.

## Yield, don't return (mid-stream)

- `return` ends the stream. Use it ONLY for "we are done" or
  "abort acknowledged".
- For "processed this item and more coming" → `yield` and continue
  the loop.
- `yield` is the unit's vocabulary. A stage that calls `return`
  before its input is exhausted is dropping work silently.

## Compose with `pipe(...stages)`

- Pipelines are built by a left-to-right `pipe()` helper that
  threads the iterable and signal through each stage.
- Declarative pipeline construction beats nested function calls.
  `pipe(source, parse, dedup, emit)` reads top-to-bottom.
- Adding a new stage is one position in the call. Removing one is
  the same.

## Terminal stage may change type

- Most stages preserve the chunk type. The terminal stage may
  convert (e.g., text chunks → audio frames, JSON events → DOM
  patches).
- The terminal stage is still a generator — it doesn't
  `Promise<void>` away the stream contract.

## Why this discipline matters

Streaming pipelines are where latency and cancellation actually
matter. The decorator pattern lets each stage be reasoned about
in isolation, swapped or reordered without touching its neighbors,
and unit-tested with a static fixture. Skipping the pattern (one
big async function with `if` ladders) means the next agent has to
re-derive the data flow every time.
