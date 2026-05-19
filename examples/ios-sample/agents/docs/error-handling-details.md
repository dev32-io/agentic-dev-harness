# Error Handling — Details & Examples

This file expands `base/rules/error-handling.md`. The rule defines
the bar; this doc shows the Result-type pattern at a boundary,
timeout patterns in four stacks, an adapter retry loop in
language-agnostic pseudo-code, a structured error log line, and the
two anti-patterns (wrap-and-rethrow noise, bare "an error
occurred").

## Result type at an HTTP boundary

A `Result<T, E>` is a discriminated union: the value or the error,
explicit at the type level. Callers cannot accidentally use the
value when the error case happened.

```text
# language-agnostic shape
type Result<T, E> =
  | { ok: true,  value: T }
  | { ok: false, error: E }
```

### Worked example — parsing an incoming HTTP body

```text
# Business logic: returns a Result, never throws.
function parseCreateOrder(raw): Result<CreateOrder, ParseError>:
  parsed = tryParseJson(raw)            # returns Result
  if not parsed.ok:
    return error(ParseError.malformedJson(detail = parsed.error))

  validated = schema.validate(parsed.value)
  if not validated.ok:
    return error(ParseError.schemaMismatch(
                  field = validated.error.field,
                  reason = validated.error.reason))

  return ok(validated.value)

# Boundary: HTTP handler catches at the edge, translates to status.
function handleCreateOrder(request):
  result = parseCreateOrder(request.body)
  if not result.ok:
    logger.warn("create-order.rejected", {
      requestId: request.id,
      error: result.error.kind,
      detail: result.error.detail,
    })
    return httpResponse(400, { error: result.error.kind })

  order = persistOrder(result.value)
  return httpResponse(201, order)
```

### Reasoning

`parseCreateOrder` cannot leak a thrown error past its signature.
Every caller sees the `Result` shape and must explicitly handle the
error branch. The HTTP boundary is the ONE place that translates
the error into an HTTP status code. If a model later refactors
`parseCreateOrder` and adds a new error variant, the type checker
forces every caller to handle it.

## Timeouts in four stacks

The rule: every external I/O has an explicit timeout. The value
lives in config, not magic-numbered in source.

### TypeScript

```ts
// timeouts.ts (config)
export const FETCH_USER_TIMEOUT_MS = Number(
  process.env.FETCH_USER_TIMEOUT_MS ?? "5000",
);

// usage
const response = await fetch(url, {
  signal: AbortSignal.timeout(FETCH_USER_TIMEOUT_MS),
});
```

### Python

```python
# config.py
FETCH_USER_TIMEOUT_S = float(os.getenv("FETCH_USER_TIMEOUT_S", "5.0"))

# usage (httpx)
async with httpx.AsyncClient(timeout=FETCH_USER_TIMEOUT_S) as client:
    response = await client.get(url)
```

### Swift

```swift
// Config.swift
enum Timeouts {
    static let fetchUser: TimeInterval = ProcessInfo.processInfo
        .environment["FETCH_USER_TIMEOUT_S"].flatMap(Double.init) ?? 5.0
}

// usage
var request = URLRequest(url: url)
request.timeoutInterval = Timeouts.fetchUser
let (data, _) = try await URLSession.shared.data(for: request)
```

### Kotlin

```kotlin
// Config.kt
object Timeouts {
    val fetchUser: Duration = System.getenv("FETCH_USER_TIMEOUT_MS")
        ?.toLongOrNull()?.milliseconds ?: 5.seconds
}

// usage (OkHttp)
val client = OkHttpClient.Builder()
    .callTimeout(Timeouts.fetchUser.toJavaDuration())
    .build()
```

### Reasoning

In every stack, the timeout has a NAME and the value comes from
config. When a model later asks "why 5000?" the answer is in the
config file, not buried in source. When the operator wants to
double the timeout under load, they change one value in one place.

## Adapter retry loop with exponential backoff

Language-agnostic pseudo-code. The shape is the same in every
stack; the primitives differ.

```text
# Transient vs fatal classification is explicit.
function classify(error) -> "transient" | "fatal":
  if error is ConnectionRefused:          return "transient"
  if error is Timeout:                    return "transient"
  if error is DnsResolutionFailed:        return "transient"
  if error is ServiceUnavailable_503:     return "transient"
  if error is InvalidConfig:              return "fatal"
  if error is MissingSecret:              return "fatal"
  if error is SchemaMismatch:             return "fatal"
  if error is AuthenticationFailed:       return "fatal"
  return "fatal"                          # default: fail loudly

function startAdapter(name, connectFn, maxAttempts=infinite):
  attempt = 0
  delay  = INITIAL_BACKOFF_MS        # e.g. 250
  while true:
    attempt = attempt + 1
    result = try(connectFn)
    if result.ok:
      logger.info("adapter.connected", { name, attempt })
      return ok(result.value)

    kind = classify(result.error)
    if kind == "fatal":
      logger.error("adapter.fatal", {
        name, attempt,
        errorKind: result.error.kind,
        detail:    result.error.detail,
      })
      exit(EXIT_CONFIG_ERROR)

    # transient
    logger.warn("adapter.retry", {
      name, attempt,
      errorKind: result.error.kind,
      delayMs:   delay,
    })
    sleep(delay)
    delay = min(delay * 2, MAX_BACKOFF_MS)   # e.g. 30_000
```

### Reasoning

The classify step is explicit code, not a bare try/catch. A
missing-secret error exits immediately — there is no point
retrying. A connection-refused error retries with backoff — the
service may be warming up. Sessions on other adapters stay live
during the retry loop; the supervisor reconnects in the background.

## Structured error log line

An error log line has FIELDS, not a sentence.

### Good

```text
logger.error("payment-processor.charge.failed", {
  requestId:   req.id,
  orderId:     order.id,
  amountCents: order.amountCents,
  currency:    order.currency,
  errorKind:   "RateLimited",
  retryAfter:  response.headers["retry-after"],
  attempt:     attempt,
  elapsedMs:   elapsed,
})
```

A reader filters by `errorKind = "RateLimited"` and sees every
rate-limit error across the fleet. A reader filters by
`orderId = ...` and sees the full lifecycle of one order.

### Bad

```text
logger.error("an error occurred")
```

This is the confession. No fields, no kind, no context. The
boundary caught the error and discarded everything that mattered.

## Anti-pattern: wrap-and-rethrow noise

A common reflex when a model "wants to add context" is to wrap and
rethrow at every layer.

### The pattern

```text
function fetchUser(id):
  try:
    return database.queryUser(id)
  catch e:
    throw new Error("fetchUser failed: " + e.message)

function getActiveUser(id):
  try:
    return fetchUser(id)
  catch e:
    throw new Error("getActiveUser failed: " + e.message)

function handleProfileRequest(request):
  try:
    return getActiveUser(request.userId)
  catch e:
    throw new Error("handleProfileRequest failed: " + e.message)
```

### What the operator sees

```text
Error: handleProfileRequest failed: getActiveUser failed: fetchUser
failed: ECONNREFUSED 127.0.0.1:5432
    at handleProfileRequest (...)
```

The stack trace is destroyed — the original `database.queryUser`
frame is gone because each wrapper threw a NEW error from a NEW
location. The reader has three sentences saying the same thing
("X failed") plus one actually-useful clause at the end.

### Fix

Let errors propagate within the layer. Catch ONCE at the boundary
and attach structured context there:

```text
function fetchUser(id):
  return database.queryUser(id)            # propagate

function getActiveUser(id):
  return fetchUser(id)                     # propagate

function handleProfileRequest(request):    # boundary
  try:
    return getActiveUser(request.userId)
  catch e:
    logger.error("profile.fetch.failed", {
      requestId: request.id,
      userId:    request.userId,
      errorKind: classify(e),
      detail:    e.message,
      stack:     e.stack,
    })
    return httpResponse(503, { error: "upstream_unavailable" })
```

The stack trace is intact. The context (requestId, userId) is
attached at the boundary, where the boundary information lives. The
intermediate layers are no longer noise.

## Anti-pattern: bare "an error occurred"

```text
try:
  doStuff()
catch e:
  logger.error("an error occurred")
```

This logs the WORST possible thing: the bare fact that something
went wrong, with no kind, no context, no input. The operator
reading the log can only conclude "something, somewhere, broke."

### Fix

```text
try:
  doStuff()
catch e:
  logger.error("doStuff.failed", {
    operation: "doStuff",
    input:     redact(input),
    errorKind: classify(e),
    detail:    e.message,
    stack:     e.stack,
  })
  throw e   # or return Result.error(...) — but ALWAYS with fields
```

If `e.message` itself is uninformative ("Error"), the classify step
is what saves the log entry — the kind ("RateLimited", "Timeout",
"SchemaMismatch") is the filterable signal.

## Never swallow silently

If a failure truly is ignorable (best-effort cache warm, optional
analytics ping), log it at DEBUG with the reason:

```text
try:
  analytics.send(event)
catch e:
  logger.debug("analytics.send.skipped", {
    eventName: event.name,
    reason:    e.message,
  })
  # intentionally no rethrow — analytics is best-effort
```

The DEBUG line is the audit trail. A bare empty `catch` block
hides the failure from operators and from future readers wondering
why analytics counts are low.
