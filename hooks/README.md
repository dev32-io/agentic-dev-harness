# Hooks

The two-hook CI pair that gives the e2e testing mandate its enforcement teeth.

## What these are

| Hook | Trigger | Command | Why |
|------|---------|---------|-----|
| **PostToolUse[Write\|Edit]** | After every file write or edit | `scripts/quality-gate.sh typecheck` | Immediate typecheck feedback. Catches regressions before the next prompt. |
| **TaskCompleted** | Before a task can be marked done | `scripts/quality-gate.sh all` | Full gate (lint + typecheck + unit tests). No task closes red. |

## Why both

Without **PostToolUse**, typecheck errors compound across turns until the agent loses track of which file broke what. Drift wins.

Without **TaskCompleted**, tasks close green-looking but actually broken — the executing-plans loop drifts forward on a false-positive trail. Later turns inherit silent breakage.

Together = a tight feedback loop. Every edit gets a fast signal; every task close gets a full gate. The mandate stops being aspirational and becomes mechanical.

## quality-gate.sh

A POSIX `sh` dispatcher that auto-detects platform from project layout:

- `package.json` + `bun.lockb` → bun (`bun run lint|typecheck|test:unit`)
- `package.json` only → node (`npm run lint|typecheck|test`)
- `pyproject.toml` or `requirements.txt` → python (`ruff check . | mypy . | pytest`)
- `build.gradle*` or `settings.gradle*` → android (`./gradlew lintDebug|assembleDebug|testDebugUnitTest`)
- `Package.swift` or `*.xcodeproj` → ios (`swiftlint | xcodebuild build -quiet | xcodebuild test -quiet`)
- none of the above → prints "unknown platform" and exits 0 (non-blocking)

**Extension pattern:** add a `run_<platform>()` function and a matching clause in `detect_platform()`. PRs welcome.

## Manual install

For users skipping `install.sh`:

1. Copy `quality-gate.sh` to `<target>/scripts/quality-gate.sh`.
2. `chmod +x <target>/scripts/quality-gate.sh`.
3. Merge `settings.example.json` hooks into `<target>/.claude/settings.json`.
