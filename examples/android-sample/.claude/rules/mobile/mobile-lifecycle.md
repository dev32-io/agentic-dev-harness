---
description: Mobile lifecycle -- background/foreground transitions, process death restore, flush-on-background.
---

# Mobile Lifecycle

Mobile processes are not long-running. The OS suspends, kills,
and resurrects them on its own schedule. Code that assumes a
continuous process is code with bugs the agent has not yet seen.
When a rule is unclear, see
`platforms/mobile/docs/mobile-lifecycle-details.md`.

## Background → foreground is a first-class state

- The transition is NOT an edge case. It is a state every screen
  passes through, often many times per session.
- On returning to foreground, code MUST refresh staleable inputs
  (clocks, auth tokens nearing expiry, network reachability) and
  re-establish observers (timers, sockets, location streams).
- Tests cover the full triple: cold start, background+resume,
  background+killed+restore. Two of three is not coverage.

## Process death + restore -- every screen rebuilds

- The OS may kill the process at any point while backgrounded.
  When the user taps the app icon, the system may either start
  fresh OR restore the prior screen stack with saved state.
- Every screen MUST be able to rebuild from a small, serializable
  snapshot of its inputs (route arguments + persisted IDs).
- Screens MUST NOT depend on in-memory singletons surviving --
  those singletons did not survive. Reach for the persistent
  store on restore.

## Resume-from-deep-link is DISTINCT from cold-launch-from-deep-link

- Cold launch: process is starting; auth state, feature flags,
  and stores are loading; the deep link must wait for readiness.
- Resume: process is alive; the deep link may arrive while a
  user is mid-task on a different screen; the navigator must
  decide whether to stack, replace, or defer.
- BOTH paths are tested. A deep link that works on cold launch
  but corrupts state on resume is a real, common bug.

## Background entry MUST flush pending writes

- When the system signals "you are about to lose foreground
  time," in-flight writes (drafts, partial form input, queued
  outbox entries) MUST be flushed to durable storage within the
  platform's short budget.
- The budget is small (single-digit seconds). Long work is the
  wrong shape -- split it; persist the intent; resume later.
- Code that assumes "we'll finish on the next tick" loses data
  on first hard kill.

## Observability of lifecycle events

- Log every lifecycle transition (foreground, background, will-
  terminate, restore) with a short, structured event.
- These breadcrumbs are how the agent diagnoses "the bug only
  happens after lunch break" -- the trail tells you the device
  was backgrounded for 90 minutes between actions.

## Why this discipline matters

The agent that ships a mobile feature is not the agent that
debugs it three months later. The lifecycle transitions are the
seams where state desyncs hide. Treating them as routine, not
exceptional, is how those bugs stay out of the field.
