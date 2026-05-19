---
description: pytest -- fixtures over setup, pytest-asyncio for async, @live marker excluded by default.
paths: "**/*.py"
---

# pytest

pytest is the test runner. It is the runner across the Python
ecosystem; alternative runners exist but choosing one is a tax
on every contributor's muscle memory. When a rule is unclear,
see `platforms/python/docs/pytest-details.md`.

## pytest is the runner

- `pytest` is the entry point. The `test` script in the project's
  Makefile / `pyproject` runs `pytest`.
- Test files: `tests/test_*.py` OR co-located `*_test.py` --
  one convention per project, written in the README.
- Test functions: `def test_<descriptive_name>():`. The name is
  what shows in failure output; make it readable.

## Fixtures over setUp/tearDown

- `@pytest.fixture` replaces the unittest `setUp` / `tearDown`
  model. Fixtures compose: a fixture can depend on other
  fixtures, scoped to function / class / module / session.
- Yield-style fixtures handle setup AND teardown in one function
  (`yield` is the boundary; `try/finally` handles cleanup). See
  the details doc for the canonical shape.
- Class-based test layout is acceptable for grouping but the
  setup/teardown methods still go through fixtures, not
  `setup_method` / `teardown_method`.

## `pytest-asyncio` for async tests

- For `async def` test functions, install `pytest-asyncio` and
  configure auto mode in `pyproject.toml`:

  ```toml
  [tool.pytest.ini_options]
  asyncio_mode = "auto"
  ```

  Every `async def test_*` is then an async test; no per-
  function `@pytest.mark.asyncio` decorator needed.
- Fixtures that yield coroutines or async generators are fully
  supported -- the same composition story applies.

## `@pytest.mark.live` for live tests; excluded by default

- Live tests hit real services. They carry the `live` marker.
- The marker is registered in `pyproject.toml` and excluded by
  default:

  ```toml
  [tool.pytest.ini_options]
  markers = ["live: tests that hit real external services"]
  addopts = "-m 'not live'"
  ```

- Default `pytest` invocation skips live tests. CI's "unit"
  step runs `pytest`; the "live" step runs `pytest -m live` on
  a schedule (nightly, pre-release).
- A live test that does not have the marker is a unit test that
  will flake on the next CI run -- a real failure to catch in
  code review.

## Parametrize for table-driven tests

- `@pytest.mark.parametrize` with named cases via
  `pytest.param(..., id="...")` gives readable failure output.
  The IDs appear in `pytest -v` so the failing row is
  immediately identifiable.
- Parametrize over a fixture by combining
  `pytest.fixture(params=...)` with the fixture-as-parameter
  pattern. See the details doc for a worked example.

## Test isolation -- no shared mutable state

- Module-scoped or session-scoped fixtures are fine for
  expensive setup (a DB connection); the data inside MUST be
  cleaned per test (transaction rollback per test, truncate
  tables, etc.).
- A test that depends on another test's leftover state is a
  test that fails when run in isolation -- a real bug, not a
  property of the test runner.

## Why this discipline matters

The pytest conventions above -- fixtures, asyncio-auto, live
markers, parametrize -- are how Python testing scales beyond a
handful of files. A repo that follows them is a repo any
contributor can navigate; one that doesn't is a repo every
contributor reads top-to-bottom before adding a test.
