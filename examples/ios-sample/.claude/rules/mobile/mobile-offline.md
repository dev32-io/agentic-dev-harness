---
description: Mobile offline-first -- observable network state, local cache, outbox sync with idempotency.
---

# Mobile Offline-First

Connectivity on mobile is intermittent by default, not by
exception. Features that only work online ship broken. When a
rule is unclear, see
`platforms/mobile/docs/mobile-offline-details.md`.

## Network state is observable, every feature branches on it

- Reachability is a value the UI subscribes to, not a thing you
  check once at function entry. The state changes mid-screen.
- Every feature has an "offline" branch: read from cache, queue
  writes, show an unobtrusive indicator that work is pending.
- The offline branch is tested. A feature that has no offline
  test does not have an offline behavior; it has an undefined
  one.

## Reads cache to a local store

- Server responses are written to a persistent local store on
  arrival. Subsequent reads hit the local store first; the
  network is a background refresher, not a blocking dependency.
- Cache entries carry a fetched-at timestamp. The UI may show
  "Updated 5 min ago" rather than pretending data is live.
- Stale-while-revalidate is the default: serve cached data
  immediately; trigger a refresh; update the UI when it lands.

## Writes queue to a local outbox

- A write produces TWO records: an optimistic local mutation
  (the UI updates immediately) AND an outbox entry describing
  the request to send when online.
- The outbox is persistent. It survives process death; the
  background syncer drains it on reconnect.
- Until the outbox entry succeeds, the UI may indicate "pending
  sync" on the affected item. Failures surface, not silently
  retry-forever.

## Sync on reconnect with idempotency

- Every outbox entry has a stable client-generated operation ID.
  Replays with the same ID are no-ops on the server side. This
  is non-negotiable -- the network WILL retry under your code.
- Order of operations is preserved within a related stream
  (e.g. edits to the same record). Across unrelated streams,
  parallelism is fine.
- Conflicts (server-side concurrent edit) are resolved with a
  named strategy: last-writer-wins, server-wins, or surface to
  user. The strategy is per-resource, written down, and tested.

## Auth tokens survive offline

- An expired token while offline is NOT a fatal error. Queued
  writes wait; reads come from cache. Token refresh happens on
  reconnect.
- Sign-out, however, MUST work offline: it clears local state
  immediately and queues the server-side revocation in the
  outbox.

## Why this discipline matters

The agent that codes assuming "the network is there" produces
features that ship to a subway, an elevator, or an airplane and
appear broken. Offline-first is not a special-case mode; it is
the default posture from which "online" is a happy enrichment.
