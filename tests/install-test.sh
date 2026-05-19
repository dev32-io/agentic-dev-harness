#!/bin/sh
# tests/install-test.sh — integration test for install.sh.
#
# Runs install.sh against fresh temp dirs and asserts the resulting tree
# satisfies the 5-case contract documented in Phase 8 of the harness plan.
#
# POSIX sh, set -eu. Tracks FAILED counter; prints each FAIL: <reason> to
# stderr; final line is "install-test.sh: OK" (exit 0) or "FAILED" (exit 1).

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d -t adh-install-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0

fail() {
    echo "FAIL: $1" >&2
    FAILED=$((FAILED + 1))
}

assert_file() {
    if [ ! -f "$1" ]; then
        fail "$2: expected file not found: $1"
    fi
}

assert_exec() {
    if [ ! -x "$1" ]; then
        fail "$2: expected executable: $1"
    fi
}

assert_contains() {
    file="$1"
    needle="$2"
    label="$3"
    if [ ! -f "$file" ]; then
        fail "$label: file missing for contains-check: $file"
        return 0
    fi
    if ! grep -Fq "$needle" "$file"; then
        fail "$label: expected '$needle' in $file"
    fi
}

assert_contains_ci() {
    # case-insensitive contains
    file="$1"
    needle="$2"
    label="$3"
    if [ ! -f "$file" ]; then
        fail "$label: file missing for contains-check: $file"
        return 0
    fi
    if ! grep -Fiq "$needle" "$file"; then
        fail "$label: expected (ci) '$needle' in $file"
    fi
}

assert_not_exists() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        fail "$2: expected NOT to exist: $1"
    fi
}

assert_dir_not_exists() {
    if [ -d "$1" ]; then
        fail "$2: expected directory NOT to exist: $1"
    fi
}

# --- C1: base-only install ---
sh "$ROOT/install.sh" --target "$TMP/c1" --platforms "" --no-chain >/dev/null 2>&1 || \
    fail "C1: install.sh exited non-zero"

assert_file    "$TMP/c1/CLAUDE.md"                                "C1"
assert_file    "$TMP/c1/.claude/rules/collaboration.md"           "C1"
assert_file    "$TMP/c1/.claude/rules/e2e-testing.md"             "C1"
assert_file    "$TMP/c1/agents/docs/collaboration-details.md"     "C1"
assert_file    "$TMP/c1/agents/docs/e2e-testing-details.md"       "C1"
assert_file    "$TMP/c1/agents/docs/learnings.md"                 "C1"
assert_file    "$TMP/c1/agents/docs/testing-knowledge.md"         "C1"
assert_file    "$TMP/c1/scripts/quality-gate.sh"                  "C1"
assert_exec    "$TMP/c1/scripts/quality-gate.sh"                  "C1"
assert_file    "$TMP/c1/.claude/settings.json"                    "C1"
assert_contains "$TMP/c1/.claude/settings.json" '"PostToolUse"'   "C1"
assert_contains "$TMP/c1/.claude/settings.json" '"TaskCompleted"' "C1"

# --- C2: web install auto-chains typescript ---
sh "$ROOT/install.sh" --target "$TMP/c2" --platforms web >/dev/null 2>&1 || \
    fail "C2: install.sh exited non-zero"

assert_file "$TMP/c2/.claude/rules/typescript/typescript.md"         "C2"
assert_file "$TMP/c2/.claude/rules/typescript/decorator-pattern.md"  "C2"
# Relaxation: platforms/web/ is empty pre-Phase-11; do NOT assert web/* files.

# --- C3: --no-chain suppresses typescript ---
sh "$ROOT/install.sh" --target "$TMP/c3" --platforms web --no-chain >/dev/null 2>&1 || \
    fail "C3: install.sh exited non-zero"

assert_dir_not_exists "$TMP/c3/.claude/rules/typescript" "C3"

# --- C4: existing CLAUDE.md NOT overwritten ---
mkdir -p "$TMP/c4"
printf 'EXISTING\n' > "$TMP/c4/CLAUDE.md"

sh "$ROOT/install.sh" --target "$TMP/c4" --platforms "" >/dev/null 2>&1 || \
    fail "C4: install.sh exited non-zero"

assert_contains "$TMP/c4/CLAUDE.md" "EXISTING" "C4"

# --- C5: --dry-run writes nothing ---
sh "$ROOT/install.sh" --target "$TMP/c5" --platforms "" --dry-run \
    > "$TMP/c5-output.log" 2>&1 || \
    fail "C5: install.sh --dry-run exited non-zero"

assert_dir_not_exists "$TMP/c5/.claude"                       "C5"
assert_contains_ci    "$TMP/c5-output.log" "would copy"       "C5"

# --- Final ---
if [ "$FAILED" -ne 0 ]; then
    echo "install-test.sh: FAILED" >&2
    exit 1
fi

echo "install-test.sh: OK"
exit 0
