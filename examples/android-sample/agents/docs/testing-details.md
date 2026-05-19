# Testing — Details & Examples

This file expands `base/rules/testing.md`. The rule defines the
bar; this doc shows worked examples for FSM testing, util-by-
consumer testing, live-tag syntax across stacks, and the common
anti-patterns to avoid.

## Worked example: FSM testing — `draft → submitted → approved → archived`

A document lifecycle has four states and four legal transitions:

```text
draft ──submit──▶ submitted ──approve──▶ approved ──archive──▶ archived
```

Illegal transitions (a partial list — real systems enumerate ALL):

- `draft ──approve──▶ ?`     (cannot approve a draft directly)
- `archived ──submit──▶ ?`   (archived is terminal)
- `approved ──submit──▶ ?`   (cannot resubmit an approved doc)

### One test per legal transition

```text
test "submit moves draft to submitted"
  given doc in state draft
  when  submit(doc)
  then  doc.state == submitted

test "approve moves submitted to approved"
  given doc in state submitted
  when  approve(doc)
  then  doc.state == approved

test "archive moves approved to archived"
  given doc in state approved
  when  archive(doc)
  then  doc.state == archived
```

### One test per illegal transition

```text
test "approve from draft is rejected"
  given doc in state draft
  when  approve(doc)
  then  raises IllegalTransition, doc.state still draft

test "submit from archived is rejected"
  given doc in state archived
  when  submit(doc)
  then  raises IllegalTransition, doc.state still archived
```

### Reasoning

If you cannot list every state and every legal/illegal edge, you do
not yet understand the machine. Draw the FSM first, then write one
test per edge. The test suite becomes a printed copy of the
diagram.

## Worked example: a util with NO direct test

`formatBytes(n)` converts a byte count to a human-readable string.
It is consumed by `renderFileList`, which is tested.

```text
// util
function formatBytes(n):
  if n < 1024 then return n + " B"
  if n < 1024*1024 then return (n/1024).toFixed(1) + " KB"
  return (n/1024/1024).toFixed(1) + " MB"
```

```text
// consumer test (this is the test that exists)
test "file list renders sizes for mixed-size inputs"
  given files = [{name: "a.txt", size: 512},
                 {name: "b.txt", size: 2048},
                 {name: "c.bin", size: 5_242_880}]
  when  renderFileList(files)
  then  output contains "512 B"
        output contains "2.0 KB"
        output contains "5.0 MB"
```

### Reasoning

`formatBytes` has no direct test. If a model rewrites it and breaks
the units, the consumer test fires — because the consumer is what
real users see. A direct unit test on `formatBytes` would re-encode
the same arithmetic the implementation already encodes, and would
need to be updated every time the formatter's output format changed
(e.g. "5.0 MB" → "5 MB"). The consumer test is stable: it asserts
that the list shows sizes, not how each cell is formatted in
isolation.

**General rule**: if a util has a bug and no other test catches it,
the missing test is for the consumer, not the util.

## Live-tag syntax across stacks

Every stack has a way to tag tests and exclude them from the
default run. Pick the one for your language and stick to it.

### Vitest

```ts
// Excluded by default. Run with: vitest run --grep @live
describe.skipIf(!process.env.RUN_LIVE)("payment provider @live", () => {
  it("authorizes a real test card", async () => { /* ... */ });
});
```

### Jest

```ts
// Default suite: describe.skip; CI live job sets RUN_LIVE=1.
const liveDescribe = process.env.RUN_LIVE ? describe : describe.skip;
liveDescribe("payment provider @live", () => {
  it("authorizes a real test card", async () => { /* ... */ });
});
```

### Pytest

```python
# pytest.ini
# [pytest]
# markers =
#     live: tests that hit real external services
# addopts = -m "not live"

import pytest

@pytest.mark.live
def test_payment_provider_authorizes_real_card():
    ...
```

Run live: `pytest -m live`. Default run excludes by `addopts`.

### Swift (XCTest)

```swift
final class PaymentLiveTests: XCTestCase {
  func test_authorizesRealTestCard() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["RUN_LIVE"] == "1",
      "Live test; set RUN_LIVE=1 to enable."
    )
    // ...
  }
}
```

### Gradle / JUnit 5

```kotlin
// In the test build config:
// tasks.test {
//   useJUnitPlatform { excludeTags("live") }
// }
// tasks.register<Test>("liveTest") {
//   useJUnitPlatform { includeTags("live") }
// }

@Tag("live")
class PaymentProviderLiveTest {
  @Test fun authorizesRealTestCard() { /* ... */ }
}
```

Default `gradle test` excludes `live`. `gradle liveTest` opts in.

## Examples — keep

### Wire-protocol contract

A schema test for a message at a process boundary. If a model
rewrites the schema without updating the consumer, this fires.

### FSM invariant

A documented invariant on a state machine (e.g. "interrupt clears
the in-flight accumulator only, not ambient state"). If a model
rewrites the machine and breaks the invariant, this fires.

### Security boundary

Each layer of an injection defense has its own contract test —
asserts that the layer rejects the inputs it claims to reject and
passes the inputs it claims to pass.

## Examples — delete

### Render assertion / copy pinning

```text
// DELETE — any copy edit breaks the test, no real defense
test "renders title"
  expect getByText("Voice profiles") to exist
```

### CSS class pinning

```text
// DELETE — any restyle breaks the test, the component still works
test "applies pending class"
  expect container.querySelector(".message--pending") to exist
```

### Pure-utility tautology

```text
// DELETE — the consumer would surface this immediately
test "returns undefined for unknown key"
  expect cache.get("missing") to be undefined
```

### Type / constant tests

```text
// DELETE — the type system already enforces this
test "Message has required fields"
```

## Anti-pattern: testing every helper while end-to-end paths are uncovered

A suite with 200 tests on individual helpers, none of which
exercises a full user-visible path, gives false confidence. The
helpers are green; the integration is silently broken because
nobody asserts the wiring.

**Symptoms**:

- High line coverage, frequent production regressions.
- Tests need updating on every refactor (because they mirror
  structure, not behavior).
- New contributors cannot find the test that pins a given user
  behavior — it doesn't exist.

**Fix**:

1. Identify the public entry points (HTTP routes, message handlers,
   exported APIs, user-facing flows).
2. Write one contract test per entry point that exercises the real
   path end-to-end (mocking only external providers at the
   process boundary).
3. Delete helper-level tests whose behavior is now covered by the
   contract test. Keep helper tests only where the helper itself is
   a public API or has FSM behavior of its own.

The test suite shrinks. Defense against drift grows.

## Mock providers at the boundary, never collaborators

When a test needs to simulate an external service (a payment
processor, a transcription API, a third-party SDK), mock at the
WIRE: the same message types and status codes the real service
returns. Never mock the unit's own collaborators.

Mocking internals re-encodes the structure you wanted freedom to
refactor. Mocking at the wire pins the contract that actually
matters and leaves the inside free to change.
