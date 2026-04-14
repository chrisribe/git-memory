#!/usr/bin/env bash
# test-basic.sh — smoke tests for git-mem core commands
# Run from the git-memory repo root: ./tests/test-basic.sh
set -euo pipefail

# --- Test harness ---
PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_MEM="$SCRIPT_DIR/../git-mem"
export GIT_MEMORY_DIR
GIT_MEMORY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-test-XXXXXX")

# Ensure git has a user configured (needed for commits in CI/clean environments)
export GIT_AUTHOR_NAME="git-mem-test"
export GIT_AUTHOR_EMAIL="test@test"
export GIT_COMMITTER_NAME="git-mem-test"
export GIT_COMMITTER_EMAIL="test@test"

cleanup() { rm -rf "$GIT_MEMORY_DIR"; }
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1" >&2; }

assert_exit_0() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

assert_exit_nonzero() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then fail "$desc"; else pass "$desc"; fi
}

assert_output_contains() {
    local desc="$1"; shift
    local needle="$1"; shift
    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | grep -qi "$needle"; then pass "$desc"; else fail "$desc (expected '$needle' in output)"; fi
}

assert_output_not_contains() {
    local desc="$1"; shift
    local needle="$1"; shift
    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | grep -qi "$needle"; then fail "$desc (found '$needle' in output)"; else pass "$desc"; fi
}

# --- Tests ---

echo "=== init ==="
assert_exit_0 "init creates repo" bash "$GIT_MEM" init
assert_output_contains "init is idempotent" "already exists" bash "$GIT_MEM" init
test -d "$GIT_MEMORY_DIR/.git" && pass "repo dir exists" || fail "repo dir exists"

echo ""
echo "=== add ==="
assert_exit_0 "add one-liner" bash "$GIT_MEM" add "[test] First memory for testing"
assert_exit_0 "add with body" bash "$GIT_MEM" add "[test][detail] Memory with body" "This is the body text with details."
assert_exit_0 "add with --yes" bash "$GIT_MEM" add --yes "[test] Another memory with yes flag"

# Verify commits exist
count=$(git -C "$GIT_MEMORY_DIR" log --oneline | wc -l | tr -d ' ')
if [[ "$count" -eq 3 ]]; then pass "3 commits stored"; else fail "expected 3 commits, got $count"; fi

# Verify body stored correctly
last_body=$(git -C "$GIT_MEMORY_DIR" log -1 --skip=1 --format="%b")
if echo "$last_body" | grep -q "body text with details"; then pass "body stored correctly"; else fail "body not found in commit"; fi

echo ""
echo "=== add: tag normalization ==="
assert_exit_0 "add with uppercase tags" bash "$GIT_MEM" add "[DRI][CosmosDB] Uppercase tags should lowercase"
subject=$(git -C "$GIT_MEMORY_DIR" log -1 --format="%s")
if [[ "$subject" == "[dri][cosmosdb] Uppercase tags should lowercase" ]]; then
    pass "tags normalized to lowercase"
else
    fail "tags not normalized: $subject"
fi

echo ""
echo "=== add: tag validation ==="
assert_output_contains "warns on missing tags" "hint" bash "$GIT_MEM" add --yes "No tags here"

echo ""
echo "=== show ==="
# Get hash of the tag normalization commit (not the "No tags" one)
hash=$(git -C "$GIT_MEMORY_DIR" log --oneline --grep="tags should lowercase" | head -1 | awk '{print $1}')
assert_output_contains "show displays subject" "tags should lowercase" bash "$GIT_MEM" show "$hash"

echo ""
echo "=== recent ==="
assert_output_contains "recent shows memories" "memory" bash "$GIT_MEM" recent
assert_output_contains "recent with count" "memory" bash "$GIT_MEM" recent 3

echo ""
echo "=== tags ==="
assert_output_contains "tags lists [test]" "test" bash "$GIT_MEM" tags
assert_output_contains "tags lists [dri]" "dri" bash "$GIT_MEM" tags

echo ""
echo "=== stats ==="
assert_output_contains "stats shows total" "Total memories" bash "$GIT_MEM" stats
assert_output_contains "stats shows path" "$GIT_MEMORY_DIR" bash "$GIT_MEM" stats

echo ""
echo "=== export ==="
export_output=$(bash "$GIT_MEM" export)
if echo "$export_output" | grep -q "First memory"; then pass "export contains memories"; else fail "export missing content"; fi
if echo "$export_output" | grep -qe '---'; then pass "export has separators"; else fail "export missing separators"; fi

echo ""
echo "=== help ==="
assert_output_contains "help shows commands" "COMMANDS" bash "$GIT_MEM" help
assert_output_contains "--help works" "COMMANDS" bash "$GIT_MEM" --help

echo ""
echo "=== error handling ==="
BAD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-bad-XXXXXX")
rm -rf "$BAD_DIR"
assert_exit_nonzero "fails without repo" env GIT_MEMORY_DIR="$BAD_DIR" bash "$GIT_MEM" add "[test] should fail"
assert_exit_nonzero "unknown command fails" bash "$GIT_MEM" notacommand

echo ""
echo "=== sync (no remote) ==="
assert_exit_nonzero "sync fails without remote" bash "$GIT_MEM" sync

# --- Summary ---
echo ""
echo "================================"
echo "  Passed: $PASS   Failed: $FAIL"
echo "================================"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
