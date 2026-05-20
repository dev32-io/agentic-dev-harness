#!/bin/sh
# tests/lint-rules-self-test.sh — verifies lint-rules.sh fires correctly
# against each fixture under tests/fixtures/lint-rules/.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/tests/fixtures/lint-rules"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILED=0

mkdir -p "$WORK/tests" "$WORK/base/rules" "$WORK/base/docs" "$WORK/platforms"
cp "$ROOT/tests/lint-rules.sh" "$WORK/tests/lint-rules.sh"

run_case() {
    expected_exit="$1"
    plat="$2"
    rule_file="$3"
    details_file="$4"

    rm -rf "$WORK/platforms"
    mkdir -p "$WORK/platforms/$plat/rules" "$WORK/platforms/$plat/docs"
    cp "$FIXTURES/$rule_file" "$WORK/platforms/$plat/rules/"
    cp "$FIXTURES/$details_file" "$WORK/platforms/$plat/docs/"

    actual_exit=0
    sh "$WORK/tests/lint-rules.sh" >/dev/null 2>&1 || actual_exit=$?
    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $rule_file expected exit $expected_exit, got $actual_exit" >&2
        FAILED=1
    else
        echo "OK: $rule_file (exit $actual_exit)"
    fi
}

run_case 0 android good-rule.md good-rule-details.md
run_case 1 android bad-too-long.md bad-too-long-details.md
run_case 1 android bad-code-block.md bad-code-block-details.md
run_case 1 android bad-no-paths.md bad-no-paths-details.md
run_case 1 mobile bad-mobile-paths.md bad-mobile-paths-details.md
run_case 0 mobile good-mobile-rule.md good-mobile-rule-details.md

if [ "$FAILED" -ne 0 ]; then
    echo "lint-rules-self-test.sh: FAILED" >&2
    exit 1
fi
echo "lint-rules-self-test.sh: OK"
exit 0
