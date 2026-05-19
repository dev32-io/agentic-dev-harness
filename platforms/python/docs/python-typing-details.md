# Python Typing -- Details & Examples

This file expands `platforms/python/rules/python-typing.md`.

## The standard module header

```python
from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field
from typing import Protocol, TypedDict

# Type-checker-only imports:
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .database import Connection
```

The `if TYPE_CHECKING:` block runs only under the type checker;
at runtime the import is skipped. Combined with future
annotations, you can refer to `Connection` as a type without
paying the import cost at runtime.

## A typed function on a public surface

```python
def load_user(
    user_id: UserId,
    *,
    conn: Connection,
    include_archived: bool = False,
) -> User | None:
    row = conn.fetch_one(
        "SELECT * FROM users WHERE id = ? AND (archived = 0 OR ?)",
        (user_id, include_archived),
    )
    return User.from_row(row) if row else None
```

Properties:
- Every parameter is typed.
- The return type names the failure shape (`User | None`).
- `*` forces `conn` and `include_archived` to be keyword
  arguments -- positional misuse is impossible.
- `UserId` is a NewType, not a bare `str`:

  ```python
  from typing import NewType
  UserId = NewType("UserId", str)

  uid = UserId("u_abc")
  fn_takes_user_id(uid)              # ok
  fn_takes_user_id("u_abc")          # mypy error -- str is not UserId
  ```

## A dataclass record

```python
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime

@dataclass(frozen=True, slots=True)
class User:
    id: UserId
    email: str
    display_name: str
    created_at: datetime
    tags: tuple[str, ...] = field(default_factory=tuple)

    @classmethod
    def from_row(cls, row: dict[str, object]) -> "User":
        return cls(
            id=UserId(str(row["id"])),
            email=str(row["email"]),
            display_name=str(row["display_name"]),
            created_at=parse_datetime(row["created_at"]),
            tags=tuple(row.get("tags", ())),
        )
```

- `frozen=True` -- immutable; safe to share across threads.
- `slots=True` -- no per-instance `__dict__`; smaller, faster.
- `field(default_factory=tuple)` -- the canonical "no mutable
  default" pattern. `tags: list[str] = []` would alias the same
  list across all instances and is one of Python's classic foot-
  guns.

## TypedDict for a JSON-shape contract

```python
from typing import TypedDict, NotRequired

class CreateUserPayload(TypedDict):
    email: str
    display_name: str
    tags: NotRequired[list[str]]

def create_user(payload: CreateUserPayload) -> User:
    # mypy knows payload["email"] is a str and payload.get("tags")
    # is list[str] | None.
    ...
```

When the data crosses a trust boundary (HTTP body, queue
message), Pydantic models add validation on top:

```python
from pydantic import BaseModel, EmailStr

class CreateUserRequest(BaseModel):
    email: EmailStr
    display_name: str
    tags: list[str] = []

def create_user_handler(body: bytes) -> Response:
    req = CreateUserRequest.model_validate_json(body)
    ...
```

`TypedDict` for "the shape we already trust"; `BaseModel` (or
`attrs` with validators) for "the shape we have to verify."

## Protocols for structural typing

```python
class SupportsSend(Protocol):
    def send(self, msg: str) -> None: ...

def fan_out(message: str, channels: Iterable[SupportsSend]) -> None:
    for ch in channels:
        ch.send(message)

# A test can pass an anonymous object; no inheritance needed.
class FakeChannel:
    def __init__(self) -> None:
        self.sent: list[str] = []
    def send(self, msg: str) -> None:
        self.sent.append(msg)

fan_out("hi", [FakeChannel()])
```

The duck-typed equivalent (`def fan_out(msg, channels):`) works
at runtime but offers nothing to the reader or the type checker.

## The `# type: ignore` etiquette

```python
# Acceptable -- specific error code + reason.
result = thirdparty.do_thing()  # type: ignore[attr-defined]  # missing stubs

# Forbidden -- bare ignore, no reason.
result = thirdparty.do_thing()  # type: ignore
```

The reason is what makes the ignore reviewable. "We accepted
that this third-party library has no stubs" is a real reason. "I
couldn't make mypy happy" is not.

## mypy configuration

```toml
# pyproject.toml
[tool.mypy]
strict = true
python_version = "3.12"
plugins = ["pydantic.mypy"]

# Tests can be slightly more relaxed; not everything else.
[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false
```

CI step:

```yaml
- name: typecheck
  run: mypy src tests
```

Strict mode catches the classes of bugs that drive the rules
here -- untyped public functions, implicit `Any`, missing
return annotations, untyped decorators.

## NewType vs alias

```python
# NewType -- nominal; the checker treats UserId as a distinct type.
UserId = NewType("UserId", str)

# Alias -- structural; the checker treats UserSlug and str interchangeably.
UserSlug = str
```

Use NewType for IDs and other "tag the meaning" cases. Use
aliases only for shorthand of a long generic type (`type
HandlerMap = dict[str, Callable[[Request], Response]]`).

## Generics -- the modern syntax

Python 3.12+ supports the inline generic syntax:

```python
def first[T](items: list[T]) -> T | None:
    return items[0] if items else None
```

For 3.11 and earlier, use `TypeVar`:

```python
from typing import TypeVar
T = TypeVar("T")
def first(items: list[T]) -> T | None: ...
```

The 3.12+ syntax is preferred where the target version allows.

(PRs welcome to deepen this platform.)
