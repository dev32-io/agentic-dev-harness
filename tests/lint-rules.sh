#!/bin/sh
# tests/lint-rules.sh — validates rule-file structural contract.
# See tests/README.md for the full contract.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
MOBILE_PLATFORMS="android ios mobile"
MOBILE_OVERLAY_PLATFORM="mobile"

fail() {
    echo "FAIL: $1" >&2
    FAILED=1
}

# Check 1: every *.md in $1 is <=100 lines.
check_loc() {
    dir="$1"
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        lines=$(wc -l < "$f" | tr -d ' ')
        if [ "$lines" -gt 100 ]; then
            fail "$f: $lines lines (max 100)"
        fi
    done
}

# Check 1-strict: every *.md in $1 is <= $2 lines. Used for mobile platforms.
check_loc_strict() {
    dir="$1"
    cap="$2"
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        lines=$(wc -l < "$f" | tr -d ' ')
        if [ "$lines" -gt "$cap" ]; then
            fail "$f: $lines lines (max $cap)"
        fi
    done
}

check_no_code_blocks() {
    dir="$1"
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        if grep -nE '^[[:space:]]*(```|~~~)' "$f" >/dev/null; then
            lineno=$(grep -nE '^[[:space:]]*(```|~~~)' "$f" | head -1 | cut -d: -f1)
            fail "$f:$lineno: fenced code block not allowed in rule files (move to details)"
        fi
    done
}

check_paths_required() {
    dir="$1"
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        has_paths=$(awk '
            { sub(/\r$/, "") }
            NR == 1 { sub(/^\xef\xbb\xbf/, ""); if ($0 != "---") exit }
            NR > 1 && /^---[[:space:]]*$/ { exit }
            NR > 1 && /^paths:/ { print "yes"; exit }
        ' "$f")
        if [ "$has_paths" != "yes" ]; then
            fail "$f: frontmatter missing required 'paths:' field"
        fi
    done
}

check_mobile_paths_globs() {
    dir="$1"
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        paths_line=$(awk '
            { sub(/\r$/, "") }
            NR == 1 { sub(/^\xef\xbb\xbf/, ""); if ($0 != "---") exit }
            NR > 1 && /^---[[:space:]]*$/ { exit }
            NR > 1 && /^paths:/ { print; exit }
        ' "$f")
        [ -n "$paths_line" ] || continue
        for required in '*.kt' '*.kts' '*.swift'; do
            if ! echo "$paths_line" | grep -Fq "$required"; then
                fail "$f: mobile rule must include '$required' in paths: (found: $paths_line)"
            fi
        done
    done
}

# Check 2/3: every rule file in $1 has paired <name>-details.md in $2.
check_paired() {
    rules_dir="$1"
    docs_dir="$2"
    [ -d "$rules_dir" ] || return 0
    for f in "$rules_dir"/*.md; do
        [ -e "$f" ] || continue
        name=$(basename "$f" .md)
        expected="$docs_dir/${name}-details.md"
        if [ ! -f "$expected" ]; then
            fail "$f: missing paired details file $expected"
        fi
    done
}

# Check 4: every rule file has valid YAML frontmatter with description: field.
# Line 1 must be "---"; "description:" must appear before the closing "---".
check_frontmatter() {
    dir="$1"
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        result=$(awk '
            { sub(/\r$/, "") }
            NR == 1 {
                sub(/^\xef\xbb\xbf/, "")
                if ($0 != "---") { state="no-open"; exit }
                next
            }
            /^---[[:space:]]*$/ {
                if (found) { state="ok" } else { state="closed-no-desc" }
                exit
            }
            /^description:/ { found=1; next }
            END {
                if (state == "") {
                    if (found) state="no-close-after-desc"
                    else state="no-close"
                }
                print state
            }
        ' "$f")
        case "$result" in
            ok) ;;
            no-open)
                fail "$f: missing YAML frontmatter (line 1 is not '---')"
                ;;
            closed-no-desc)
                fail "$f: frontmatter missing 'description:' field"
                ;;
            no-close)
                fail "$f: frontmatter never closes with '---'"
                ;;
            no-close-after-desc)
                fail "$f: frontmatter never closes with '---' after 'description:'"
                ;;
            *)
                fail "$f: frontmatter check returned unexpected state '$result'"
                ;;
        esac
    done
}

# Check 5: no base/rules/*.md may have paths: restricted to a single language ext.
check_no_lang_glob_in_base() {
    dir="$ROOT/base/rules"
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        # Extract the paths: line(s) from frontmatter only.
        paths_line=$(awk '
            { sub(/\r$/, "") }
            NR == 1 { sub(/^\xef\xbb\xbf/, ""); if ($0 != "---") exit }
            NR > 1 && /^---[[:space:]]*$/ { exit }
            NR > 1 && /^paths:/ { print; exit }
        ' "$f")
        [ -n "$paths_line" ] || continue
        for ext in '*.ts' '*.tsx' '*.kt' '*.swift' '*.py' '*.rs' '*.go'; do
            if echo "$paths_line" | grep -Fq "$ext"; then
                fail "$f: base/rules may not use language-specific glob '$ext' (move to platforms/)"
            fi
        done
    done
}

check_loc "$ROOT/base/rules"
check_paired "$ROOT/base/rules" "$ROOT/base/docs"
check_frontmatter "$ROOT/base/rules"
check_no_lang_glob_in_base

if [ -d "$ROOT/platforms" ]; then
    for plat_rules in "$ROOT"/platforms/*/rules; do
        [ -d "$plat_rules" ] || continue
        plat=$(dirname "$plat_rules")
        plat_name=$(basename "$plat")
        plat_docs="$plat/docs"
        is_mobile=0
        for mp in $MOBILE_PLATFORMS; do
            if [ "$plat_name" = "$mp" ]; then is_mobile=1; break; fi
        done
        if [ "$is_mobile" -eq 1 ]; then
            check_loc_strict "$plat_rules" 40
            check_no_code_blocks "$plat_rules"
            check_paths_required "$plat_rules"
            if [ "$plat_name" = "mobile" ]; then
                check_mobile_paths_globs "$plat_rules"
            fi
        else
            check_loc "$plat_rules"
        fi
        check_paired "$plat_rules" "$plat_docs"
        check_frontmatter "$plat_rules"
    done
fi

if [ "$FAILED" -ne 0 ]; then
    echo "lint-rules.sh: FAILED" >&2
    exit 1
fi

echo "lint-rules.sh: OK"
exit 0
