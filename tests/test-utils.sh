#!/usr/bin/env bash
# test-utils.sh — shared test harness for git-mem tests
# Source this from test scripts: source "$SCRIPT_DIR/test-utils.sh"

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)"
GIT_MEM="$SCRIPT_DIR/../git-mem"

# Ensure git has a user configured (needed for commits in CI/clean environments)
export GIT_AUTHOR_NAME="git-mem-test"
export GIT_AUTHOR_EMAIL="test@test"
export GIT_COMMITTER_NAME="git-mem-test"
export GIT_COMMITTER_EMAIL="test@test"

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
    if echo "$output" | grep -Fqi "$needle"; then pass "$desc"; else fail "$desc (expected '$needle' in output)"; fi
}

assert_output_not_contains() {
    local desc="$1"; shift
    local needle="$1"; shift
    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | grep -Fqi "$needle"; then fail "$desc (found '$needle' in output)"; else pass "$desc"; fi
}

print_summary() {
    echo ""
    echo "================================"
    echo "  Passed: $PASS   Failed: $FAIL"
    echo "================================"
    [[ $FAIL -eq 0 ]] && exit 0 || exit 1
}
