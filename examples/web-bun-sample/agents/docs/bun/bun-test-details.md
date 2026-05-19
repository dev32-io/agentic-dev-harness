# Bun Test -- Details & Examples

This file expands `platforms/bun/rules/bun-test.md`.

## A canonical test file

```ts
// src/cart/Cart.test.ts
import { describe, test, expect, beforeEach } from "bun:test";
import { Cart } from "./Cart";

describe("Cart", () => {
    let cart: Cart;

    beforeEach(() => {
        cart = new Cart();
    });

    test("starts empty", () => {
        expect(cart.itemCount).toBe(0);
        expect(cart.total).toBe(0);
    });

    test("adds an item", () => {
        cart.add({ sku: "ABC", price: 100, qty: 2 });
        expect(cart.itemCount).toBe(2);
        expect(cart.total).toBe(200);
    });

    test.each([
        { qty: 0,  expectError: true  },
        { qty: 1,  expectError: false },
        { qty: 99, expectError: false },
        { qty: -1, expectError: true  },
    ])("validates qty=$qty", ({ qty, expectError }) => {
        const op = () => cart.add({ sku: "X", price: 1, qty });
        if (expectError) expect(op).toThrow();
        else             expect(op).not.toThrow();
    });
});
```

`describe` / `test` / `expect` from `bun:test` are the same
shape as Jest's. Migration from Jest is mostly
`from "jest"` → `from "bun:test"`.

## Mocks -- the Bun-native form

```ts
import { mock, test, expect } from "bun:test";
import { fetchProduct } from "./products";

test("renders product name", async () => {
    const fakeFetch = mock(async (_id: string) => ({
        id:   "p1",
        name: "Widget",
    }));

    // Inject the mock at the seam (constructor / param), not via
    // global module-replacement hacks.
    const result = await fetchProduct("p1", { transport: fakeFetch });
    expect(result.name).toBe("Widget");
    expect(fakeFetch).toHaveBeenCalledWith("p1");
});
```

`bun:test`'s `mock()` is a Jest-compatible spy. Prefer
constructor / parameter injection ("the seam") to module-level
mocking; the seam version is testable in any runtime.

## Snapshots that get reviewed

```ts
test("formats a price tag", () => {
    expect(formatPrice({ amount: 1995, currency: "USD" }))
        .toMatchSnapshot();
});
```

First run produces:

```text
// __snapshots__/price.test.ts.snap
exports[`formats a price tag 1`] = `"$19.95"`;
```

The `.snap` file is committed. On the next test run, an
unintended change shows up as a snapshot diff in the PR.
Reviewer asks: "is this currency-formatting change
intentional?" -- and either approves or rejects. The snapshot is
documentation of the function's output.

To accept an intentional change:

```text
$ bun test --update-snapshots
$ git diff __snapshots__/   # review the change
$ git add __snapshots__/
$ git commit -m "feat(price): show grouping separators"
```

## Watch -- dev only

```json
// package.json
{
    "scripts": {
        "test":       "bun test",
        "test:watch": "bun test --watch"
    }
}
```

CI calls `npm run test` (or `bun run test`); CI never calls
`test:watch`. The watch process never exits voluntarily; CI
would either hang or hit a timeout.

## The `.only` / `.skip` grep step

```yaml
# .github/workflows/ci.yml
jobs:
    test:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4
            - uses: oven-sh/setup-bun@v1
              with:
                  bun-version: 1.2
            - run: bun install --frozen-lockfile

            - name: forbid test.only / test.skip / describe.only
              run: |
                  set -e
                  if grep -RnE '\b(test|it|describe)\.(only|skip)\b' \
                      --include='*.test.ts' --include='*.spec.ts' \
                      src tests; then
                      echo "::error::test.only / test.skip / describe.only found"
                      exit 1
                  fi

            - run: bun test
```

If a contributor pushes `test.only` to debug, CI rejects it.
That is the desired behavior: forgetting `test.only` is one of
the all-time top "tests pass but actually most of them did not
run" causes.

## Layout choice -- write it down

The README's "Project layout" section names the choice:

```markdown
## Project layout

- `src/`           -- application code; unit tests co-located
                      (`Cart.ts` + `Cart.test.ts`).
- `tests/live/`    -- integration tests against real services.
                      Run with `npm run test:live` (CI nightly).
- `__snapshots__/` -- next to the test that produced them.
```

The agent that picks up the codebase reads this and knows where
to place new tests. Without the section, every new file is a
50/50 coin flip on where it goes.

## Common edge cases

```ts
// Async + AbortSignal cleanup.
test("respects abort", async () => {
    const ac = new AbortController();
    setTimeout(() => ac.abort(), 50);
    await expect(
        longOperation({ signal: ac.signal }),
    ).rejects.toThrow(/abort/i);
});

// Time control.
import { setSystemTime } from "bun:test";
test("at exactly midnight", () => {
    setSystemTime(new Date("2026-01-01T00:00:00Z"));
    expect(currentDay()).toBe("2026-01-01");
});
```

## Why the discipline pays off

The cost of `.only` / `.skip` / watch-in-CI / un-reviewed
snapshots is real: tests that don't run, hangs that consume CI
minutes, PRs whose green CI lights are lying. The remedies are
all small, mechanical, and worth running on every commit.

(PRs welcome to deepen this platform.)
