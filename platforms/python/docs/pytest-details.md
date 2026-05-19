# pytest -- Details & Examples

This file expands `platforms/python/rules/pytest.md`.

## A canonical `pyproject.toml` test config

```toml
[tool.pytest.ini_options]
minversion = "8.0"
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = [
    "-m", "not live",
    "--strict-markers",
    "--strict-config",
    "-ra",
]
markers = [
    "live: tests that hit real external services (excluded by default)",
    "slow: tests that take more than 5 seconds",
]
```

`--strict-markers` rejects unknown markers; a typo in
`@pytest.mark.lvie` fails CI rather than silently doing nothing.

## A composing-fixture cascade

```python
from __future__ import annotations
from collections.abc import Iterator
from pathlib import Path
import tempfile
import shutil
import pytest
from app.db import Connection, migrate

@pytest.fixture(scope="session")
def db_url() -> str:
    return "postgresql://test:test@localhost/test"

@pytest.fixture(scope="session")
def schema(db_url: str) -> None:
    """Apply migrations once per test session."""
    migrate(db_url)

@pytest.fixture
def conn(db_url: str, schema: None) -> Iterator[Connection]:
    """A fresh transaction per test; rolled back at teardown."""
    c = Connection.connect(db_url)
    c.begin()
    try:
        yield c
    finally:
        c.rollback()
        c.close()

def test_inserts_a_user(conn: Connection) -> None:
    conn.execute("INSERT INTO users (id, email) VALUES (?, ?)", ("u1", "a@b"))
    row = conn.fetch_one("SELECT email FROM users WHERE id = ?", ("u1",))
    assert row["email"] == "a@b"
```

Properties:
- The schema migration runs once per session.
- Every test gets a fresh transaction that is rolled back.
- Tests are independent without each having to truncate tables.

## Async tests with `pytest-asyncio` in auto mode

```python
import pytest
import httpx

@pytest.fixture
async def client() -> AsyncIterator[httpx.AsyncClient]:
    async with httpx.AsyncClient(base_url="http://app:8000") as c:
        yield c

async def test_health(client: httpx.AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"ok": True}
```

With `asyncio_mode = "auto"`, no `@pytest.mark.asyncio` decorator
is needed. Async fixtures and tests Just Work.

## Live tests -- marker + separate CI step

```python
import pytest
from app.email import send_email

@pytest.mark.live
def test_sends_a_real_email() -> None:
    # Hits the real SES sandbox.
    result = send_email(to="qa@example.com", subject="hi", body="...")
    assert result.message_id is not None
```

CI:

```yaml
# .github/workflows/ci.yml
- name: unit tests
  run: pytest

# .github/workflows/nightly.yml
- name: live tests
  run: pytest -m live
  env:
    AWS_ACCESS_KEY_ID:     ${{ secrets.AWS_TEST_KEY }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_TEST_SECRET }}
```

Default `pytest` invocation respects `addopts = ["-m", "not
live"]` -- unit-test runs skip the marked tests.

## Parametrize -- the table

```python
import pytest
from app.cart import Cart, Item

@pytest.mark.parametrize(
    ("price", "qty", "expected_total"),
    [
        pytest.param(100,  1, 100,    id="one-item"),
        pytest.param(100,  2, 200,    id="two-items"),
        pytest.param(99,   3, 297,    id="odd-price"),
        pytest.param(0,    5, 0,      id="zero-price"),
    ],
)
def test_total(price: int, qty: int, expected_total: int) -> None:
    cart = Cart()
    cart.add(Item(sku="X", price=price, qty=qty))
    assert cart.total == expected_total
```

`pytest -v` output:

```text
tests/test_cart.py::test_total[one-item]    PASSED
tests/test_cart.py::test_total[two-items]   PASSED
tests/test_cart.py::test_total[odd-price]   PASSED
tests/test_cart.py::test_total[zero-price]  PASSED
```

Readable. A failure points at the named case, not at "test_total
case index 2."

## Property-based testing with Hypothesis

For input domains that lend themselves to "for all X" claims,
hypothesis composes cleanly with pytest:

```python
from hypothesis import given, strategies as st

@given(qty=st.integers(min_value=1, max_value=100))
def test_total_is_qty_times_price(qty: int) -> None:
    cart = Cart()
    cart.add(Item(sku="X", price=10, qty=qty))
    assert cart.total == 10 * qty
```

Add it to the toolkit; do not require it for every test.

## Common test-isolation foot-guns

```python
# WRONG -- module-scope mutable. Tests interfere.
_RECORDS: list[Record] = []

def test_one() -> None:
    _RECORDS.append(Record("a"))

def test_two() -> None:
    # Sometimes empty, sometimes has Record("a") -- depending on
    # which test ran first.
    assert _RECORDS == []
```

```python
# RIGHT -- a fixture provides a fresh container per test.
@pytest.fixture
def records() -> list[Record]:
    return []

def test_one(records: list[Record]) -> None:
    records.append(Record("a"))
    assert records == [Record("a")]

def test_two(records: list[Record]) -> None:
    assert records == []
```

## Output capture and logging

```python
def test_emits_info_log(caplog: pytest.LogCaptureFixture) -> None:
    with caplog.at_level("INFO"):
        do_a_thing()
    assert "thing.done" in caplog.text
```

`caplog` is a pytest builtin fixture; it captures `logging`
output for assertions. `capsys` does the same for `stdout` /
`stderr`. Both replace the "redirect stdout" gymnastics of
plain unittest.

## When to use `unittest.TestCase`

Almost never in new code. `unittest.TestCase` works under
pytest, but mixing the two styles means new contributors have to
learn both. Pick one (pytest-style functions and fixtures) and
stay there.

(PRs welcome to deepen this platform.)
