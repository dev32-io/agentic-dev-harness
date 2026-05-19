# Logging — Details & Examples

This file expands `base/rules/logging.md`. The rule defines the
bar; this doc shows tag-format syntax across five stacks, a
canonical structured-fields example, the logtape ~180-character
truncation gotcha, and the no-PII anti-pattern with the fix.

## Tag-format syntax across five stacks

The shape is the same in every stack: a three-segment dotted name
(`<area>.<sub-area>.<surface>`) carried on every line. The
mechanism differs.

### TypeScript with logtape

```ts
import { getLogger } from "@logtape/logtape";

const logger = getLogger(["auth", "session", "refresh"]);

logger.info("refresh.attempted", {
  userId,
  requestId,
  tokenPrefix: token.slice(0, 8),
});
```

logtape uses an array name. The array elements join into the dotted
tag in the formatted output.

### TypeScript with pino

```ts
import pino from "pino";

const root = pino();
const logger = root.child({ component: "auth.session.refresh" });

logger.info({ userId, requestId, tokenPrefix: token.slice(0, 8) },
  "refresh.attempted");
```

pino uses a `child` logger with a bound `component` field. Every
line emitted by `logger` carries the same tag.

### Python with structlog

```python
import structlog

logger = structlog.get_logger().bind(component="auth.session.refresh")

logger.info("refresh.attempted",
            user_id=user_id,
            request_id=request_id,
            token_prefix=token[:8])
```

structlog's `bind` returns a new logger with the bound context.
Every line from `logger` carries `component="auth.session.refresh"`.

### Swift with `os.Logger`

```swift
import os

let logger = Logger(subsystem: "com.example.app",
                    category: "auth.session.refresh")

logger.info("""
  refresh.attempted userId=\(userId, privacy: .private) \
  requestId=\(requestId) tokenPrefix=\(token.prefix(8))
  """)
```

`os.Logger`'s `category` is the dotted tag. Note `privacy: .private`
on the `userId` interpolation — `os.Logger` enforces redaction at
the call site.

### Kotlin with Timber

```kotlin
Timber.tag("auth.session.refresh")
    .i("refresh.attempted userId=%s requestId=%s tokenPrefix=%s",
        userId, requestId, token.take(8))
```

Timber's `.tag(...)` sets the dotted tag for the next log call. For
a permanent tag, write a thin wrapper that auto-tags every call in
a class.

### Reasoning

Each stack has a NATIVE way to attach a structured tag. Use it.
Inventing your own tag scheme (prepending `[auth.session.refresh]`
to every message string) defeats the structured filtering the
stack already provides — operators cannot filter on a substring of
the message as cheaply as on a real field.

## Canonical structured-fields example

A log line for an e-commerce app, at the boundary where a checkout
request lands.

```text
logger.info("checkout.submitted", {
  user_id:        userRecord.id,
  request_id:     request.id,
  tenant_id:      request.tenantId,
  cart_id:        cart.id,
  item_count:     cart.items.length,
  total_cents:    cart.totalCents,
  currency:       cart.currency,
  payment_method: "card_token",     # not the token itself
})
```

Filtering by `cart_id` gives the full lifecycle of one cart.
Filtering by `tenant_id` gives one customer's traffic. Filtering
by `user_id` gives one user's session. Aggregating `total_cents`
by tenant gives revenue-per-tenant. None of this is possible if
the fields are flattened into a sentence-string.

### Anti-pattern — the sentence-string

```text
logger.info(
  "User " + userRecord.id + " submitted a checkout for $" +
  (cart.totalCents / 100) + " in cart " + cart.id
)
```

Operators must parse English to extract IDs. Aggregations are
impossible. Two checkouts a millisecond apart are indistinguishable
unless someone parses the sentence. The information is THERE; it
just isn't reachable.

## The logtape ~180-character truncation gotcha

Verbatim finding from real-world use: in logtape, structured field
values truncate around 180 characters by default. A prompt logged
in a `prompt` field gets silently cut. The truncated line LOOKS
complete in the rendered output — there is no warning, no ellipsis
unless the formatter inserts one. Two days later you wonder why
the LLM call failed and the prompt field shows half a prompt.

### Workarounds

**Option A — write the long string to a file, log the filepath.**

```ts
const logger = getLogger(["llm", "openai", "chat"]);

async function logPromptToFile(prompt: string): Promise<string> {
  const ts = Date.now();
  const path = `/var/log/app/prompts/${ts}.txt`;
  await fs.writeFile(path, prompt, "utf-8");
  return path;
}

logger.debug("prompt.sent", {
  requestId,
  promptLength: prompt.length,
  promptPath:   await logPromptToFile(prompt),
});
```

The log line stays short and indexable. The full prompt is on disk
under a path correlated by `requestId`.

**Option B — chunk explicitly into numbered fields.**

```ts
function chunk(s: string, size: number): string[] {
  const out: string[] = [];
  for (let i = 0; i < s.length; i += size) out.push(s.slice(i, i + size));
  return out;
}

const parts = chunk(prompt, 150);   // safely under the 180 cap
const fields: Record<string, unknown> = {
  requestId,
  promptLength: prompt.length,
  promptChunks: parts.length,
};
parts.forEach((p, i) => { fields[`promptPart${i}`] = p; });
logger.debug("prompt.sent", fields);
```

Verbose, but every chunk is below the cap and every chunk is
visible.

**Option C — hash the prompt, store separately.**

```ts
logger.debug("prompt.sent", {
  requestId,
  promptLength: prompt.length,
  promptHash:   sha256(prompt).slice(0, 16),
});
// Store the hash → prompt mapping in a content-addressed store
// or in an evals database, keyed by promptHash.
```

### General lesson

Every structured logger has limits — field-length caps, total-line
caps, dropped-key behavior on collisions. Verify your stack's
limits and document them in the project's logging-details file.
Don't assume "structured" means "no truncation."

## Anti-pattern: logging raw user input

```text
# WRONG
logger.info("login.attempt", {
  email:    request.body.email,
  password: request.body.password,
  ip:       request.ip,
})
```

This log line contains:

- A raw email (PII).
- A plaintext password (catastrophic — never log this).
- A raw IP (PII in many jurisdictions).

### Fix — mask at the call site

```text
import { hashEmail } from "../security/redact.ts";

logger.info("login.attempt", {
  email_hash:    hashEmail(request.body.email),   # SHA-256, first 16
  password_seen: request.body.password.length > 0, # boolean, not value
  ip_prefix:     maskIp(request.ip),               # e.g. 203.0.113.0
  user_agent:    request.headers["user-agent"],
})
```

- `email_hash` is filterable (you can find every attempt for one
  user by hashing their email outside the log pipeline). It is not
  reversible without a brute force.
- `password_seen` is the only useful signal about the password
  field — was it sent at all? The value itself is forbidden.
- `ip_prefix` keeps geographic signal without keeping the user's
  exact address.

### Reasoning

The log sanitizer at the sink is the LAST line of defense, not the
FIRST. Code review must catch raw PII before it reaches the
sanitizer; the sanitizer catches the bugs that escape review. If
the only thing standing between a leaked password and the audit
log is a regex on the sink, the audit log is already wrong.

## Truncate string previews

A short string preview (a transcript snippet, a tool-call argument,
a parsed token) MUST be capped at a SAFE length — say, 120
characters — and never include sensitive substrings.

```text
function preview(s: string, max = 120): string {
  if (s.length <= max) return s;
  return s.slice(0, max) + "…";
}

logger.debug("transcript.chunk", {
  requestId,
  preview:    preview(chunk.text),
  fullLength: chunk.text.length,
})
```

The preview is for the operator's eyes when scanning. The full
content lives on disk or in an evals store, addressable by
`requestId`.

## When in doubt, log

Logging discipline does NOT mean "log less." It means "log
structured, log filterable, log without PII." A line you can
filter is cheap. A line you cannot filter is dead text — but ALSO,
a session with no log lines is a black box. Err on the side of
more INFO lines around lifecycle events, more DEBUG lines around
data transitions, and fewer free-text sentences anywhere.
