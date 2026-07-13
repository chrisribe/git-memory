#!/usr/bin/env bash
# test-source.sh — tests for git-mem source (folder-based multi-source)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-utils.sh"

# Primary store + sources dir side-by-side
export GIT_MEMORY_DIR
GIT_MEMORY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-src-test-XXXXXX")
export GIT_MEMORY_SOURCES_DIR="${GIT_MEMORY_DIR}-sources"

cleanup() { rm -rf "$GIT_MEMORY_DIR" "$GIT_MEMORY_SOURCES_DIR"; }
trap cleanup EXIT

# Helper: create a minimal git-memory repo at $1 with one commit tagged $2
make_repo() {
    local path="$1" tag="$2"
    mkdir -p "$path"
    git init -q "$path"
    git -C "$path" config user.email "t@t"
    git -C "$path" config user.name "T"
    git -C "$path" commit --allow-empty -m "[$tag] Memory from $tag repo"
}

# --- Setup ---
bash "$GIT_MEM" init >/dev/null 2>&1
bash "$GIT_MEM" add --yes "[mine] Primary repo memory" >/dev/null 2>&1

make_repo /tmp/git-mem-src-team-$$ team
make_repo /tmp/git-mem-src-hermes-$$ hermes

cleanup_externals() {
    rm -rf /tmp/git-mem-src-team-$$ /tmp/git-mem-src-hermes-$$
}
trap "cleanup; cleanup_externals" EXIT

# --- source add (local path → symlink) ---
echo "=== source add ==="
assert_exit_0         "add local source (team)"   bash "$GIT_MEM" source add team   /tmp/git-mem-src-team-$$
assert_exit_0         "add local source (hermes)" bash "$GIT_MEM" source add hermes /tmp/git-mem-src-hermes-$$
assert_exit_nonzero   "add duplicate name fails"  bash "$GIT_MEM" source add team   /tmp/git-mem-src-team-$$
assert_exit_nonzero   "add primary as source fails" bash "$GIT_MEM" source add mine "$GIT_MEMORY_DIR"
assert_exit_nonzero   "reserved name 'mine' rejected" bash "$GIT_MEM" source add mine /tmp/git-mem-src-team-$$
assert_output_contains "scp-style SSH URL treated as remote clone" "Clone failed" \
    bash "$GIT_MEM" source add sshremote1 git@127.0.0.1:/tmp/git-mem-nonexistent-$$
assert_output_not_contains "scp-style SSH URL not treated as local path" "Not a git repository" \
    bash "$GIT_MEM" source add sshremote2 git@127.0.0.1:/tmp/git-mem-nonexistent-$$

# Verify symlinks created
[[ -L "$GIT_MEMORY_SOURCES_DIR/team" ]]   && pass "team is a symlink"   || fail "team symlink missing"
[[ -L "$GIT_MEMORY_SOURCES_DIR/hermes" ]] && pass "hermes is a symlink" || fail "hermes symlink missing"

# --- source list ---
echo ""
echo "=== source list ==="
assert_output_contains "list shows team"   "team"   bash "$GIT_MEM" source list
assert_output_contains "list shows hermes" "hermes" bash "$GIT_MEM" source list
assert_output_contains "list shows Primary" "Primary" bash "$GIT_MEM" source list
assert_output_contains "list shows symlink indicator" "symlink" bash "$GIT_MEM" source list

# --- search across sources ---
echo ""
echo "=== search (multi-source) ==="
assert_output_contains "search finds primary memory"   "Primary repo memory"   bash "$GIT_MEM" search primary
assert_output_contains "search finds team source"      "Memory from team"      bash "$GIT_MEM" search team
assert_output_contains "search finds hermes source"    "Memory from hermes"    bash "$GIT_MEM" search hermes
assert_output_contains "search attributes team result" "[team]"                bash "$GIT_MEM" search team

# --- search --json includes source field ---
echo ""
echo "=== search --json (source attribution) ==="
json=$(bash "$GIT_MEM" search --json team 2>/dev/null)
if echo "$json" | grep -q '"source":"team"'; then
    pass "--json includes source field"
else
    fail "--json missing source field (got: $json)"
fi
if echo "$json" | grep -q '"date":"'; then
    pass "--json includes non-empty date for source result"
else
    fail "--json date empty for source result (got: $json)"
fi
if echo "$json" | grep -q '"subject":"'; then
    pass "--json includes non-empty subject for source result"
else
    fail "--json subject empty for source result (got: $json)"
fi

# --- source disable ---
echo ""
echo "=== source disable ==="
assert_exit_0 "disable team" bash "$GIT_MEM" source disable team
[[ -d "$GIT_MEMORY_SOURCES_DIR/team.disabled" ]] && pass "team.disabled dir exists" || fail "team.disabled not created"
[[ ! -e "$GIT_MEMORY_SOURCES_DIR/team" ]]         && pass "team (enabled) removed"  || fail "old team dir still exists"

assert_output_not_contains "disabled source excluded from search" "Memory from team" bash "$GIT_MEM" search team
assert_output_contains     "primary still searched when source disabled" "Primary repo memory" bash "$GIT_MEM" search primary

assert_exit_0 "disable idempotent (already disabled)" bash "$GIT_MEM" source disable team

# --- source enable ---
echo ""
echo "=== source enable ==="
assert_exit_0 "enable team" bash "$GIT_MEM" source enable team
[[ -d "$GIT_MEMORY_SOURCES_DIR/team" ]] && pass "team re-enabled dir exists" || fail "team dir missing after enable"
assert_output_contains "re-enabled source appears in search" "Memory from team" bash "$GIT_MEM" search team
assert_exit_0 "enable idempotent (already enabled)" bash "$GIT_MEM" source enable team

# --- source remove (symlink) ---
echo ""
echo "=== source remove ==="
assert_exit_0 "remove hermes (symlink)" bash "$GIT_MEM" source remove hermes
[[ ! -e "$GIT_MEMORY_SOURCES_DIR/hermes" ]]   && pass "hermes symlink gone"         || fail "hermes symlink still present"
[[ -d "/tmp/git-mem-src-hermes-$$" ]]          && pass "original hermes repo intact" || fail "original hermes repo deleted"
assert_exit_nonzero "remove non-existent fails" bash "$GIT_MEM" source remove hermes

# --- source list after changes ---
echo ""
echo "=== source list (post-remove) ==="
assert_output_contains     "list still shows team"        "team"   bash "$GIT_MEM" source list
assert_output_not_contains "list no longer shows hermes" "hermes" bash "$GIT_MEM" source list

print_summary
