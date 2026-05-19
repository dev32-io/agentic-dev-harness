#!/bin/sh
# install.sh — agentic-dev-harness installer (POSIX sh).
#
# Lays down base rules + selected platform overlays into a target project.
# Resolves chained overlays (e.g. web/node/bun pull in typescript) by reading
# platforms/<p>/chain.yaml. CLAUDE.md and .claude/settings.json are written
# only when absent (never overwritten). --dry-run announces what WOULD be
# copied without touching the filesystem.

set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"

# --- defaults ---
TARGET=""
PLATFORMS=""
NO_CHAIN=0
DRY_RUN=0

usage() {
    cat <<USAGE_EOF
Usage: install.sh --target <dir> [--platforms <comma-list>] [--no-chain] [--dry-run]

Options:
  --target <dir>        Target project directory (required). Will be created.
  --platforms <list>    Comma-separated platform overlays (e.g. "web,python").
                        Default: "" (base rules only).
  --no-chain            Do not auto-include chained-by overlays (e.g. typescript).
  --dry-run             Print "would copy" lines; write nothing.
  -h, --help            Show this help.
USAGE_EOF
}

# --- arg parse ---
while [ $# -gt 0 ]; do
    case "$1" in
        --target)
            [ $# -ge 2 ] || { echo "install.sh: --target requires a value" >&2; exit 64; }
            TARGET="$2"
            shift 2
            ;;
        --platforms)
            [ $# -ge 2 ] || { echo "install.sh: --platforms requires a value" >&2; exit 64; }
            PLATFORMS="$2"
            shift 2
            ;;
        --no-chain)
            NO_CHAIN=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "install.sh: unknown argument: $1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo "install.sh: --target is required" >&2
    usage >&2
    exit 64
fi

# --- helpers ---

# is_in <needle> <space-separated-haystack>
is_in() {
    needle="$1"
    haystack=" $2 "
    case "$haystack" in
        *" $needle "*) return 0 ;;
        *) return 1 ;;
    esac
}

# parse_yaml_list <yaml-file> <top-level-key>
# Echoes the items of a simple YAML list:
#   key:
#     - item1
#     - item2
# One item per line. Stops at the next top-level key (line starting with
# non-space, non-dash, non-hash, containing ":").
parse_yaml_list() {
    file="$1"
    key="$2"
    [ -f "$file" ] || return 0
    awk -v key="$key" '
        BEGIN { in_block = 0 }
        {
            sub(/\r$/, "")
            sub(/#.*$/, "")        # strip comments
        }
        # detect top-level key opening the list
        $0 ~ "^"key":[[:space:]]*$" {
            in_block = 1
            next
        }
        in_block == 1 {
            # leave block when we hit another top-level key or non-indented content
            if ($0 ~ /^[A-Za-z_][A-Za-z0-9_-]*:/) {
                in_block = 0
                next
            }
            # match list item: leading spaces, dash, value
            if (match($0, /^[[:space:]]*-[[:space:]]*/)) {
                item = substr($0, RSTART + RLENGTH)
                # strip surrounding quotes/whitespace
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
                gsub(/^"|"$/, "", item)
                gsub(/^'\''|'\''$/, "", item)
                if (item != "") print item
            }
        }
    ' "$file"
}

# announce_copy <src> <dst>
announce_copy() {
    echo "would copy $1 -> $2"
}

# do_copy_file <src> <dst>  — copy a single file, mkdir -p parent
do_copy_file() {
    src="$1"
    dst="$2"
    [ -f "$src" ] || return 0
    if [ "$DRY_RUN" -eq 1 ]; then
        announce_copy "$src" "$dst"
        return 0
    fi
    dst_dir="$(dirname "$dst")"
    mkdir -p "$dst_dir"
    cp "$src" "$dst"
}

# do_copy_glob <src-dir> <pattern> <dst-dir>
# Copies every file in src-dir matching pattern into dst-dir.
do_copy_glob() {
    src_dir="$1"
    pattern="$2"
    dst_dir="$3"
    [ -d "$src_dir" ] || return 0
    if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$dst_dir"
    fi
    # iterate
    for f in "$src_dir"/$pattern; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        do_copy_file "$f" "$dst_dir/$base"
    done
}

# do_copy_tree <src-dir> <dst-dir>
# Recursively copies every regular file under src-dir into dst-dir, preserving
# relative subpaths. Pure POSIX (no `cp -R` of dotfiles trickiness).
do_copy_tree() {
    src_dir="$1"
    dst_dir="$2"
    [ -d "$src_dir" ] || return 0
    if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$dst_dir"
    fi
    # find files; strip the src prefix to get relative path.
    find "$src_dir" -type f | while IFS= read -r f; do
        rel="${f#"$src_dir"/}"
        do_copy_file "$f" "$dst_dir/$rel"
    done
}

# --- resolve effective platforms ---

# Start with user list (space-separated).
EFFECTIVE=""
if [ -n "$PLATFORMS" ]; then
    old_ifs="$IFS"
    IFS=,
    for p in $PLATFORMS; do
        # trim
        p="$(echo "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [ -n "$p" ] || continue
        if ! is_in "$p" "$EFFECTIVE"; then
            EFFECTIVE="${EFFECTIVE:+$EFFECTIVE }$p"
        fi
    done
    IFS="$old_ifs"
fi

# Chain resolution: scan every platforms/*/chain.yaml.
#  - chain: <list>       — for each user platform <u>, include items declared
#                          in platforms/<u>/chain.yaml under `chain:`.
#  - chained-by: <list>  — for each overlay <o> whose chain.yaml declares
#                          `chained-by: [a, b, c]`, include <o> when any of
#                          a/b/c is in the effective list.
if [ "$NO_CHAIN" -eq 0 ] && [ -n "$EFFECTIVE" ]; then
    # Fixed-point: keep resolving until no additions.
    changed=1
    while [ "$changed" -eq 1 ]; do
        changed=0

        # (1) chain: lists owned by user platforms
        for u in $EFFECTIVE; do
            chain_file="$ROOT/platforms/$u/chain.yaml"
            [ -f "$chain_file" ] || continue
            for item in $(parse_yaml_list "$chain_file" "chain"); do
                if ! is_in "$item" "$EFFECTIVE"; then
                    EFFECTIVE="$EFFECTIVE $item"
                    changed=1
                fi
            done
        done

        # (2) chained-by relationships
        for chain_file in "$ROOT"/platforms/*/chain.yaml; do
            [ -f "$chain_file" ] || continue
            overlay="$(basename "$(dirname "$chain_file")")"
            if is_in "$overlay" "$EFFECTIVE"; then
                continue
            fi
            for trigger in $(parse_yaml_list "$chain_file" "chained-by"); do
                if is_in "$trigger" "$EFFECTIVE"; then
                    EFFECTIVE="$EFFECTIVE $overlay"
                    changed=1
                    break
                fi
            done
        done
    done
fi

# --- prep target ---
if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$TARGET"
fi

# --- copy base rules + docs ---
do_copy_glob "$ROOT/base/rules" "*.md"             "$TARGET/.claude/rules"
do_copy_glob "$ROOT/base/docs"  "*-details.md"     "$TARGET/agents/docs"

# --- copy platform overlays ---
for p in $EFFECTIVE; do
    [ -n "$p" ] || continue
    plat_dir="$ROOT/platforms/$p"
    if [ ! -d "$plat_dir" ]; then
        echo "install.sh: notice: platforms/$p not found, skipping" >&2
        continue
    fi
    do_copy_tree "$plat_dir/rules" "$TARGET/.claude/rules/$p"
    do_copy_tree "$plat_dir/docs"  "$TARGET/agents/docs/$p"
    if [ -d "$plat_dir/qa" ]; then
        do_copy_tree "$plat_dir/qa" "$TARGET/qa/$p"
    fi
done

# --- CLAUDE.md (no overwrite) ---
if [ -f "$TARGET/CLAUDE.md" ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "install.sh: CLAUDE.md already exists at $TARGET/CLAUDE.md, leaving it untouched"
else
    do_copy_file "$ROOT/CLAUDE.md.template" "$TARGET/CLAUDE.md"
fi

# --- hooks/settings.json (no overwrite) ---
if [ -f "$TARGET/.claude/settings.json" ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "install.sh: WARNING: .claude/settings.json already exists; merge hooks manually from hooks/settings.example.json — both PostToolUse and TaskCompleted required"
else
    do_copy_file "$ROOT/hooks/settings.example.json" "$TARGET/.claude/settings.json"
fi

# --- quality-gate.sh (always refresh, chmod +x) ---
do_copy_file "$ROOT/hooks/quality-gate.sh" "$TARGET/scripts/quality-gate.sh"
if [ "$DRY_RUN" -eq 0 ] && [ -f "$TARGET/scripts/quality-gate.sh" ]; then
    chmod +x "$TARGET/scripts/quality-gate.sh"
fi

# --- learnings seeds (no overwrite) ---
if [ -f "$TARGET/agents/docs/learnings.md" ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "install.sh: agents/docs/learnings.md exists; leaving it untouched"
else
    do_copy_file "$ROOT/learnings/learnings.md" "$TARGET/agents/docs/learnings.md"
fi

if [ -f "$TARGET/agents/docs/testing-knowledge.md" ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "install.sh: agents/docs/testing-knowledge.md exists; leaving it untouched"
else
    do_copy_file "$ROOT/learnings/testing-knowledge.md" "$TARGET/agents/docs/testing-knowledge.md"
fi

# --- summary ---
if [ -z "$EFFECTIVE" ]; then
    summary_plats="(none — base only)"
else
    summary_plats="$EFFECTIVE"
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] agentic-dev-harness would install to $TARGET // platforms applied: $summary_plats"
else
    echo "agentic-dev-harness installed to $TARGET // platforms applied: $summary_plats"
fi

exit 0
