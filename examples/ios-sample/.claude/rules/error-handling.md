---
description: Catch at boundaries, propagate within, explicit timeouts, structured error context. Language-agnostic.
---

# Error Handling

Errors are not exceptional events to be hidden — they are control
flow. An agent rereading a stack trace six hours into a session
needs to know what was attempted, on what input, and how the
attempt failed. Vague errors and lost stack traces destroy the only
signal you have when something goes wrong.
When a rule is unclear, see `base/docs/error-handling-details.md`.

## Catch at boundaries, not at every call site

- Catch errors at SYSTEM BOUNDARIES only. Boundaries are:
  process I/O (stdin/stdout, file handles), network I/O (HTTP
  handlers, WebSocket handlers, RPC servers), public API surface
  exposed to other modules or processes, and subprocess
  invocation.
- Within a layer, let errors propagate. Wrap-and-rethrow at every
  call site destroys stack traces and floods logs with noise
  ("error in foo: error in bar: error in baz: real reason").
- The boundary handler is responsible for translating the failure
  into the contract its caller expects (HTTP status, RPC response,
  exit code, structured log entry).

## Result types where the caller MUST decide

- Use a `Result<T, E>` / `Either<E, T>` / `Try<T>` type at
  boundaries where the caller is REQUIRED to handle the failure
  case. Throwing means "exceptional, you usually don't think about
  it." Returning a `Result` means "expected, you MUST decide."
- Parsing, validation, schema decoding, and any operation that
  routinely fails on bad input are `Result`-shaped, not
  exception-shaped.
- Inside business logic, prefer `Result` over throwing. Reserve
  throwing for truly unrecoverable cases (out of memory, invariant
  violation, bug-class assertions).

## Every external I/O has an explicit timeout

- No unbounded waits. EVER. A hung dependency must not hang the
  agent.
- Timeout values live in config (env var, config file, constant
  named in a shared constants module). Not magic-numbered in
  source.
- The timeout error carries the operation name, the target, and
  the elapsed time — never a bare "timeout."

## Adapter `start()` / `connect()` / `init()` behavior split

Adapters that connect to external services on startup MUST
distinguish two failure modes:

- **Transient** (network blip, service warming, connection
  refused on cold start): retry with exponential backoff, log
  WARN with the reason, do NOT crash the process. Sessions stay
  live and accept input on other channels while the supervisor
  reconnects in the background.
- **Fatal** (bad config, missing required secret, schema
  mismatch, version incompatibility): exit immediately with a
  clear ERROR message naming the missing/invalid value. There is
  no point retrying — the operator must act.

The distinction MUST be explicit in code. A bare `catch`-all that
treats every failure as transient masks bad config; one that
treats every failure as fatal makes the system fragile to network
flaps.

## Structured error context

- Every error MUST carry: what was attempted, what input
  triggered it, what specifically failed.
- Errors are structured records (fields), not formatted strings.
  The formatted string is a presentation choice for the boundary
  handler.
- Never emit a bare "an error occurred" — that is a confession
  that the error was discarded.

## Never swallow errors silently

- An empty catch block is a bug. If a failure is genuinely
  expected and ignorable, log it at DEBUG with the reason.
- "Best effort" operations still log the failure. Operators must
  be able to see what was attempted and what was skipped.
