# Decorator-Pattern Pipelines — Details & Examples

This file expands `platforms/typescript/rules/decorator-pattern.md`.
The rule defines the bar; this doc gives the full `pipe()`
implementation with generics, an end-to-end SSE worked example,
an AbortSignal propagation walkthrough, backpressure notes, and
the three anti-patterns that show up most often.

## The `pipe()` helper

Each stage has the shape `(input, signal) => AsyncIterable<T>`.
`pipe()` threads the iterable through each stage left-to-right.
Overloads carry the type from one stage to the next so the
composed pipeline keeps full type-safety.

```typescript
// pipe.ts
export type Stage<TIn, TOut> = (
  input: AsyncIterable<TIn>,
  signal: AbortSignal,
) => AsyncIterable<TOut>;

export function pipe<A, B>(
  source: AsyncIterable<A>,
  s1: Stage<A, B>,
  signal: AbortSignal,
): AsyncIterable<B>;
export function pipe<A, B, C>(
  source: AsyncIterable<A>,
  s1: Stage<A, B>,
  s2: Stage<B, C>,
  signal: AbortSignal,
): AsyncIterable<C>;
export function pipe<A, B, C, D>(
  source: AsyncIterable<A>,
  s1: Stage<A, B>,
  s2: Stage<B, C>,
  s3: Stage<C, D>,
  signal: AbortSignal,
): AsyncIterable<D>;
export function pipe<A, B, C, D, E>(
  source: AsyncIterable<A>,
  s1: Stage<A, B>,
  s2: Stage<B, C>,
  s3: Stage<C, D>,
  s4: Stage<D, E>,
  signal: AbortSignal,
): AsyncIterable<E>;
export function pipe(
  source: AsyncIterable<unknown>,
  ...rest: ReadonlyArray<Stage<unknown, unknown> | AbortSignal>
): AsyncIterable<unknown> {
  const signal = rest[rest.length - 1] as AbortSignal;
  const stages = rest.slice(0, -1) as ReadonlyArray<Stage<unknown, unknown>>;
  return stages.reduce<AsyncIterable<unknown>>(
    (acc, stage) => stage(acc, signal),
    source,
  );
}
```

The implementation is one `reduce`. The work is in the overloads
— they are what give the caller a typed result without a single
`as` cast.

## End-to-end worked example: HTTP SSE → UI

A four-stage pipeline. Source: HTTP SSE stream of JSON events.
Stages: parse, dedup, emit. Each stage is its own file in
practice; shown together here.

### Stage 1 — source: SSE bytes to text chunks

```typescript
// sse-source.ts
export async function* sseSource(
  url: string,
  signal: AbortSignal,
): AsyncGenerator<string> {
  const res = await fetch(url, { signal });
  if (!res.body) return;
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  try {
    while (true) {
      if (signal.aborted) return;
      const { value, done } = await reader.read();
      if (done) return;
      const text = decoder.decode(value, { stream: true });
      for (const block of text.split("\n\n")) {
        if (!block.startsWith("data: ")) continue;
        yield block.slice(6);
      }
    }
  } finally {
    reader.releaseLock();
  }
}
```

### Stage 2 — parse JSON

```typescript
// parse-stage.ts
type Event = { id: string; type: string; payload: unknown };

export async function* parseStage(
  input: AsyncIterable<string>,
  signal: AbortSignal,
): AsyncGenerator<Event> {
  for await (const raw of input) {
    if (signal.aborted) return;
    try {
      yield JSON.parse(raw) as Event;
    } catch {
      // skip malformed; do not throw — that would kill the stream
    }
  }
}
```

### Stage 3 — dedupe by `id`

```typescript
// dedup-stage.ts
export async function* dedupStage(
  input: AsyncIterable<Event>,
  signal: AbortSignal,
): AsyncGenerator<Event> {
  const seen = new Set<string>();
  for await (const event of input) {
    if (signal.aborted) return;
    if (seen.has(event.id)) continue;
    seen.add(event.id);
    yield event;
  }
}
```

`seen` is internal to this stage. Other stages never see it.

### Stage 4 — emit to UI (terminal, changes type to void-ish)

```typescript
// emit-stage.ts
export async function* emitStage(
  input: AsyncIterable<Event>,
  signal: AbortSignal,
): AsyncGenerator<{ delivered: string }> {
  for await (const event of input) {
    if (signal.aborted) return;
    document.dispatchEvent(new CustomEvent("app:event", { detail: event }));
    yield { delivered: event.id };
  }
}
```

### Composing with `pipe()`

```typescript
const controller = new AbortController();

const pipeline = pipe(
  sseSource("/stream", controller.signal),
  parseStage,
  dedupStage,
  emitStage,
  controller.signal,
);

for await (const ack of pipeline) {
  console.log("delivered", ack.delivered);
}
```

Reading the call top-to-bottom matches the data flow. Adding a
new stage (rate-limit, log, redact) is one line inserted at the
right position.

## AbortSignal propagation walkthrough

Cancellation in this pattern is structural — you do not need to
forward "stop" messages between stages. The signal does the work.

### What happens when the consumer cancels

1. UI code calls `controller.abort()`.
2. The signal flips to `aborted: true`.
3. The `for await` consumer at the bottom may `break` (or it may
   continue iterating; either is fine).
4. The terminal stage's `for await (const event of input)` runs
   its next `await`. If the upstream is paused awaiting `fetch`,
   the `fetch` rejects with an `AbortError` because the same
   signal was passed in.
5. The rejection unwinds through every `for await`. Each stage's
   `for await` finishes its loop without entering the body, so
   no extra `yield` happens.
6. Each stage's generator function returns. Any `finally` blocks
   run (e.g., releasing the reader lock in the source).
7. References to internal buffers (`seen`, decoders) drop and
   become eligible for GC.

No stage explicitly checks `signal.aborted` in this walkthrough —
the signal-aware `fetch` is what unblocks the chain. The explicit
`if (signal.aborted) return;` checks are belt-and-braces for two
cases: (1) the stage does its own long awaits unrelated to
`fetch`, and (2) the stage was about to yield but has not yet
done so when abort fired.

### Stage-level abort check pattern

```typescript
async function* stage(
  input: AsyncIterable<T>,
  signal: AbortSignal,
): AsyncGenerator<T> {
  for await (const item of input) {
    if (signal.aborted) return;       // check before processing
    const next = transform(item);
    if (signal.aborted) return;       // check before yielding
    yield next;
  }
}
```

Two checks per loop, both cheap. The pre-process check catches
the case where the consumer aborted while upstream was producing.
The pre-yield check catches the case where `transform` itself
took time.

### What the consumer pattern looks like

```typescript
try {
  for await (const ack of pipeline) {
    if (controller.signal.aborted) break;
    handle(ack);
  }
} catch (e) {
  if ((e as Error).name === "AbortError") return; // expected
  throw e;
}
```

`AbortError` is normal control flow — catch it and return. Other
errors are bugs and must propagate.

## Backpressure handling

`for await` provides natural backpressure: the upstream generator
only advances when the downstream is ready for the next item.
When the downstream is slow, every `yield` in the chain awaits
until the downstream loops back.

### Default case — natural backpressure is enough

```typescript
for await (const event of pipeline) {
  await renderSlow(event); // upstream blocks here
}
```

While `renderSlow` runs, no stage advances. No memory grows.

### When to add explicit buffer

Add a buffer only when the source has hard timing (e.g., a WS
that drops messages if not consumed within N ms) and the
downstream's pauses can exceed that window.

```typescript
async function* buffered<T>(
  input: AsyncIterable<T>,
  capacity: number,
  signal: AbortSignal,
): AsyncGenerator<T> {
  const queue: T[] = [];
  let done = false;

  (async () => {
    for await (const item of input) {
      if (signal.aborted) return;
      if (queue.length >= capacity) queue.shift(); // drop-oldest
      queue.push(item);
    }
    done = true;
  })();

  while (!done || queue.length > 0) {
    if (signal.aborted) return;
    if (queue.length === 0) {
      await new Promise((r) => setTimeout(r, 1));
      continue;
    }
    yield queue.shift()!;
  }
}
```

`drop-oldest` is one policy; `drop-newest` and `block-producer`
are the other two. Picking one is a product decision, not a
default. The default — no buffer — is correct most of the time.

## Anti-patterns

### Anti-pattern 1 — collecting into an array "to be safe"

```typescript
// BAD
async function processEvents(input: AsyncIterable<Event>): Promise<Event[]> {
  const all: Event[] = [];
  for await (const e of input) all.push(e);
  return all.map(transform);
}
```

This forces the consumer to wait for the source to finish before
seeing the first item. Latency goes from "first byte" to "last
byte". Memory grows linearly with stream length. On an unbounded
source (websocket, SSE), it never returns.

Fix: keep it a generator. Yield each item as it transforms.

### Anti-pattern 2 — ignoring `AbortSignal`

```typescript
// BAD
async function* parse(input: AsyncIterable<string>): AsyncGenerator<Event> {
  for await (const raw of input) {
    yield JSON.parse(raw) as Event; // no signal at all
  }
}
```

When the user cancels, `input` keeps producing (e.g., a buffered
source). This stage keeps yielding. The consumer's `break` did
exit its loop, but every upstream stage continues until the
source naturally finishes — leaking work and CPU.

Fix: accept `signal: AbortSignal`, check `signal.aborted` at the
yield boundary, AND pass the same signal into any awaitable inside
the stage so the awaits themselves cancel.

### Anti-pattern 3 — `setInterval` instead of an async generator

```typescript
// BAD
function startPolling(onEvent: (e: Event) => void): () => void {
  const id = setInterval(async () => {
    const e = await fetchNext();
    onEvent(e);
  }, 500);
  return () => clearInterval(id);
}
```

`setInterval` has no cancellation handshake with the work in
flight. Callbacks already scheduled run after `clearInterval`.
Errors thrown in the callback have no `try`/`catch` site. There
is no backpressure — if `fetchNext` takes longer than 500ms,
multiple in-flight requests stack up.

Fix:

```typescript
async function* polling(
  signal: AbortSignal,
): AsyncGenerator<Event> {
  while (!signal.aborted) {
    yield await fetchNext(signal);
    await sleep(500, signal);
  }
}
```

One in-flight request at a time, abortable, composable with
`pipe()`. Same line count, real cancellation semantics.

## Testing a stage with a fixture iterable

Every stage being a pure function over an `AsyncIterable` means
the test fixture is one line:

```typescript
async function* fixture<T>(items: ReadonlyArray<T>): AsyncGenerator<T> {
  for (const item of items) yield item;
}

test("dedupStage drops repeated ids", async () => {
  const signal = new AbortController().signal;
  const input = fixture<Event>([
    { id: "a", type: "x", payload: 1 },
    { id: "a", type: "x", payload: 1 },
    { id: "b", type: "y", payload: 2 },
  ]);
  const out: Event[] = [];
  for await (const e of dedupStage(input, signal)) out.push(e);
  expect(out.map((e) => e.id)).toEqual(["a", "b"]);
});
```

No mocks. No setup. The stage is testable because its only
inputs are an iterable and a signal.

## Why these patterns matter

Streaming is where latency, memory, and cancellation collide. The
decorator pattern picks one shape — async generator in, async
generator out, signal threaded through — and applies it
everywhere. Each stage becomes a unit a single agent can hold in
its head: one file, one responsibility, one fixture-driven test.
The composition is a `pipe()` call you can read top-to-bottom.
The cancellation story is the signal alone. There is no extra
coordination layer to learn or maintain.
