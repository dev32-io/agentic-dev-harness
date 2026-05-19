---
description: Structured tags, four log levels, no PII, filterable fields. The debuggable-agentic-loops rule.
---

# Logging

The harness operates over agentic loops. Logs are the only window
into what happened. Write them like you'll be reading them in a
debugger — because you will, on the day the loop misbehaves and
all you have is the audit trail.
When a rule is unclear, see `base/docs/logging-details.md`.

## Structured tag format

- Every log line carries a tag of the form
  `[<area>.<sub-area>.<surface>]` — three levels, dot-separated,
  lowercase, no spaces.
- Examples: `[auth.session.refresh]`, `[payments.webhook.stripe]`,
  `[ingest.parser.csv]`.
- The tag answers "where am I in the system?" without reading the
  file path. Filtering on a tag prefix
  (`auth.*`, `auth.session.*`) is the operator's primary tool.
- Pick the stack's idiomatic mechanism (hierarchical logger names,
  `child` loggers, bound contexts, categories). See the details
  doc for stack-specific syntax.

## Four log levels, no others

- **DEBUG** — developer-only tracing. Per-chunk, per-token,
  per-decision. OFF in production. Never gate behavior on a DEBUG
  line.
- **INFO** — events worth knowing about: request received, job
  started, state transitioned, session connected. Lifecycle
  events that an operator browsing a healthy system wants to see.
- **WARN** — recoverable concern: retried after a failure, fell
  back to a degraded path, used a deprecated code path, rate-limit
  approached but not hit. Carries a `reason` field.
- **ERROR** — action needed: invariant violated, request failed
  permanently, fatal config problem, dropped message. A human or
  paging system needs to look.

Anything more granular than these four is noise. Anything less is
too coarse to filter on.

## No PII

- Never log raw user input, emails, names, payment data, auth
  tokens, session cookies, or anything else a privacy review would
  flag.
- Mask at the CALL SITE, not at the sink. `email_hash` not
  `email`. `card_last4` not `card_number`. `token_prefix` (first 8
  chars) not `token`.
- A log sanitizer at the sink is a safety net, not the policy.
  Code reviewed for "is this PII?" before it reaches the sink.

## Filterable structured fields

- Every log line carries structured fields, not just a message.
  At minimum: a unit-of-work identifier for the domain
  (`user_id`, `request_id`, `tenant_id`, `order_id`, whatever your
  units are).
- A log line you cannot filter is dead text. If `grep` is the only
  way to find a related entry, the line wasn't structured enough.
- Numeric fields (`elapsed_ms`, `bytes`, `queue_depth`, `attempt`)
  are first-class. They are what dashboards aggregate on.

## Field-truncation gotcha

Most structured loggers TRUNCATE field values around 180
characters by default. A long string (an LLM prompt, a serialized
payload, a stack trace) logged in a single field gets silently
cut. The line looks complete; the data isn't.

- Verify your stack's truncation point. Document it in the
  project's `logging-details.md`.
- Long strings need their own field name with explicit handling:
  write the full content to a file and log the FILEPATH, or chunk
  the string into numbered fields, or hash it.

## Why this matters

A long-running agent generates thousands of log lines per session.
The operator debugging a regression six hours in cannot read every
line — they must FILTER. Structured tags, filterable fields, and
correct levels are what make filtering possible. Treat logging as
part of code-complete: if a bug report cannot be traced end-to-end
from this file's logs, the file is not done.
