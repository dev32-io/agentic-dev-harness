#!/bin/sh
# quality-gate.sh — platform-aware quality gate dispatcher
#
# Usage: quality-gate.sh <lint|typecheck|test|all>
#
# Auto-detects platform from project layout and dispatches to the appropriate
# run_<platform> function. Each platform handles lint, typecheck, test, all.
# Extension pattern: add a run_<platform>() function + a detect_platform clause.

set -eu

SCOPE="${1:-}"

case "$SCOPE" in
  lint|typecheck|test|all) ;;
  "") echo "Usage: $0 <lint|typecheck|test|all>" >&2; exit 64 ;;
  *)  echo "Unknown scope: $SCOPE (expected lint|typecheck|test|all)" >&2; exit 64 ;;
esac

# ─── Platform detection ───
detect_platform() {
  if [ -f package.json ] && [ -f bun.lockb ]; then
    echo bun
  elif [ -f package.json ]; then
    echo node
  elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then
    echo python
  elif [ -f build.gradle ] || [ -f build.gradle.kts ] || [ -f settings.gradle ] || [ -f settings.gradle.kts ]; then
    echo android
  elif [ -f Package.swift ] || [ -n "$(find . -maxdepth 2 -name '*.xcodeproj' -print -quit 2>/dev/null)" ]; then
    echo ios
  else
    echo unknown
  fi
}

# ─── Platform runners ───
run_bun() {
  case "$1" in
    lint)      bun run lint ;;
    typecheck) bun run typecheck ;;
    test)      bun run test:unit ;;
    all)       bun run lint && bun run typecheck && bun run test:unit ;;
  esac
}

run_node() {
  case "$1" in
    lint)      npm run lint ;;
    typecheck) npm run typecheck ;;
    test)      npm run test ;;
    all)       npm run lint && npm run typecheck && npm run test ;;
  esac
}

run_python() {
  case "$1" in
    lint)      ruff check . ;;
    typecheck) mypy . ;;
    test)      pytest ;;
    all)       ruff check . && mypy . && pytest ;;
  esac
}

run_android() {
  case "$1" in
    lint)      ./gradlew lintDebug ;;
    typecheck) ./gradlew assembleDebug ;;
    test)      ./gradlew testDebugUnitTest ;;
    all)       ./gradlew lintDebug && ./gradlew assembleDebug && ./gradlew testDebugUnitTest ;;
  esac
}

run_ios() {
  case "$1" in
    lint)
      if command -v swiftlint >/dev/null 2>&1; then
        swiftlint
      else
        echo "swiftlint not installed; skipping lint" >&2
      fi
      ;;
    typecheck) xcodebuild build -quiet ;;
    test)      xcodebuild test -quiet ;;
    all)
      if command -v swiftlint >/dev/null 2>&1; then
        swiftlint
      else
        echo "swiftlint not installed; skipping lint" >&2
      fi
      xcodebuild build -quiet && xcodebuild test -quiet
      ;;
  esac
}

# ─── Dispatch ───
PLATFORM="$(detect_platform)"

case "$PLATFORM" in
  bun)     run_bun "$SCOPE" ;;
  node)    run_node "$SCOPE" ;;
  python)  run_python "$SCOPE" ;;
  android) run_android "$SCOPE" ;;
  ios)     run_ios "$SCOPE" ;;
  unknown) echo "unknown platform: no recognized project layout (package.json, pyproject.toml, build.gradle*, Package.swift, *.xcodeproj)" >&2; exit 0 ;;
esac
