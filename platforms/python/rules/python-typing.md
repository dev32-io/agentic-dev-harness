---
description: Python typing -- future annotations, type hints public surface, mypy strict, dataclasses for records.
paths: "**/*.py"
---

# Python Typing

Python is gradually typed. Code that opts out of types is code
the agent and the next maintainer cannot reason about from
signatures alone. When a rule is unclear, see
`platforms/python/docs/python-typing-details.md`.

## `from __future__ import annotations` at the top of every module

```python
from __future__ import annotations
```

- Defers evaluation of annotations until inspection. Forward
  references to classes defined later in the file Just Work; no
  string-quoted types needed.
- Removes a class of runtime-import cost for typing-only imports
  (combined with `if TYPE_CHECKING: import ...`).
- On Python 3.12+ this becomes the default in some scenarios,
  but the explicit import is portable across the supported range.

## Type hints on every public function signature

- Public means: anything not prefixed with `_`. Every parameter
  and the return type carry an annotation.
- Private helpers may omit hints if the body is short enough
  that the inferred types are obvious -- but the bar is low;
  prefer hints there too.
- `def foo(x):` in a public surface is FORBIDDEN. The compiler
  (mypy) cannot help the caller without the type.

## `mypy --strict` in CI

- `mypy --strict` is the CI bar. Flags it enables include
  `disallow_untyped_defs`, `warn_return_any`,
  `no_implicit_optional`, and others -- the union is the strict
  posture.
- Per-module `[mypy-tests.*]` relaxations are acceptable for
  tests if needed, but production code MUST pass strict.
- `# type: ignore` comments carry a reason in a trailing comment
  (`# type: ignore[attr-defined]  # third-party stub lacks this`).
  No bare `# type: ignore`.

## Dataclasses over plain classes for value records

- `@dataclass(frozen=True, slots=True)` for records of values
  (no mutable identity). Free `__init__`, `__repr__`, `__eq__`.
- Use `field(default_factory=list)` for mutable defaults; never
  bare `[]` in a default-arg position.
- Reach for `class` only when you need behavior with identity
  (a service object, a stateful client).

## `TypedDict` over `dict` literals for structured data

- A function that takes a dict with specific keys should take a
  `TypedDict` -- the keys are typed and IDE-completable.
- `dict[str, Any]` is a code smell on a public surface; it
  abdicates the typing discipline.
- For API contracts and JSON shapes, `TypedDict` (or
  `pydantic.BaseModel` if validation is needed) is the right
  shape.

## `Protocol` for structural typing at the seam

- When a function takes "anything with a `.send()` method,"
  declare a `Protocol` with `def send(self, msg: str) -> None`
  and parametrize on it. The implementations do not need to
  inherit.
- Protocols make tests easier (any object with the methods is
  accepted) and document the dependency explicitly.

## Why this discipline matters

Untyped Python is Python that fails at the boundary the type
system was built to defend. `mypy --strict` + dataclasses +
TypedDict turn a script into a system the next agent can pick
up from signatures alone -- the same property Swift, Kotlin,
and TypeScript provide.
