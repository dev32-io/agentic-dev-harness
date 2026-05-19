---
description: What to test, what not to test, FSM-as-source-of-truth, contract-first discipline.
---

# Testing

Tests are a defensive mechanism against model drift. A test earns
its place ONLY by pinning behavior that real consumers depend on.
When a rule is unclear, see `base/docs/testing-details.md`.

## What tests guard

- **Wire / protocol contracts** at process boundaries (client↔server,
  service↔service, app↔external API, message-bus payloads).
- **FSM transitions** — every legal transition has a test; every
  illegal transition has a test asserting it is rejected.
- **Security boundaries** — auth, token validation, injection
  defense, sanitization of logs and user input.
- **Public APIs** — the surface other modules call against.
- **Behavior promised in docs** — if a README or spec promises a
  guarantee, that guarantee has a test.

## What tests do NOT guard

- Pure utility functions that are exercised by other tests through
  their consumer. If a util has a bug and no other test catches it,
  the missing test is for the CONSUMER, not the util.
- Factories, builders, fixtures, DI plumbing.
- Trivial getters, setters, and passthroughs.
- Private helpers. Test the public behavior that calls them.
- Type definitions, constant values, copy strings, CSS class names.

Borderline tests get deleted, not kept.

## FSM as the source of truth

- If a module has states, draw the FSM first. If you cannot
  enumerate the states, you cannot test the machine.
- One test per legal transition. One test per illegal transition.
- Every reachable state must be reachable in test. Every state with
  a wait must have a timeout-guard test.
- Sad paths get tested harder than happy paths: interrupt during
  transition, double-event, abort-mid-flight, disconnect.

## Contract-first discipline

- Write the test that captures the behavior BEFORE writing the
  implementation. The test is the spec made executable.
- A test added after the fact tends to ratify whatever the code
  does. A test added first forces you to name the contract.
- Test names read as full sentences:
  `it("returns/throws/emits X when Y")`.

## No reflection-based testing

- Reaching into private methods via reflection to "test internals"
  means the public API was designed wrong. Either the internal is
  actually part of the contract (promote it) or it isn't (test the
  public behavior that uses it).
- Mocking your own collaborators re-encodes the structure you wanted
  freedom to refactor. Mock external providers, not internals.

## Live tests are tagged and gated

- Tests that hit a real external service (live API, real device,
  paid provider) MUST be tagged (`@live`, `pytest.mark.live`,
  `describe.live`, JUnit tag `live`, etc.).
- Live tests are EXCLUDED from the default test command.
- Live tests run in a dedicated CI job with credentials, on a
  schedule or on opt-in.
- A developer running `<test command>` locally MUST NOT need
  external credentials.

## Exhaustiveness over coverage percentage

A coverage number is a vanity metric. What matters: every reachable
state is reached, every legal transition is tested, every illegal
one is rejected, every wait has a timeout guard. Coverage
percentage will follow.
