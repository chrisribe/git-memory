#!/usr/bin/env bash
# test-dedup.sh — dedup detection tests for git-mem
# Run from the git-memory repo root: ./tests/test-dedup.sh
set -euo pipefail

# --- Test harness ---
PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_MEM="$SCRIPT_DIR/../git-mem"
export GIT_MEMORY_DIR
GIT_MEMORY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-dedup-XXXXXX")

export GIT_AUTHOR_NAME="git-mem-test"
export GIT_AUTHOR_EMAIL="test@test"
export GIT_COMMITTER_NAME="git-mem-test"
export GIT_COMMITTER_EMAIL="test@test"

cleanup() { rm -rf "$GIT_MEMORY_DIR"; }
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1" >&2; }

# --- Setup ---
bash "$GIT_MEM" init >/dev/null 2>&1

echo "=== Dedup detection ==="

# Store a baseline memory
bash "$GIT_MEM" add --yes "[dri][cosmosdb] RU exhaustion is container ceiling not hot partition"
count_before=$(git -C "$GIT_MEMORY_DIR" log --oneline | wc -l | tr -d ' ')

# Try storing a near-duplicate (should trigger warning)
output=$(bash "$GIT_MEM" add --yes "[dri][cosmosdb] RU exhaustion is container ceiling check autoscale" 2>&1)
if echo "$output" | grep -qi "duplicate"; then
    pass "detects near-duplicate"
else
    fail "did not detect near-duplicate"
fi

# --yes should store anyway despite duplicate warning
count_after=$(git -C "$GIT_MEMORY_DIR" log --oneline | wc -l | tr -d ' ')
if [[ $count_after -gt $count_before ]]; then
    pass "--yes stores despite duplicate"
else
    fail "--yes did not store"
fi

echo ""
echo "=== No false positives ==="

# Completely different memory should not trigger warning
output=$(bash "$GIT_MEM" add --yes "[workflow][git] Always rebase before pushing feature branches" 2>&1)
if echo "$output" | grep -qi "duplicate"; then
    fail "false positive on unrelated memory"
else
    pass "no false positive on unrelated memory"
fi

echo ""
echo "=== Short messages ==="

# Very short messages (fewer significant words) should use lower threshold
bash "$GIT_MEM" add --yes "[gotcha] Check permissions first"
output=$(bash "$GIT_MEM" add --yes "[gotcha] Check permissions always" 2>&1)
if echo "$output" | grep -qi "duplicate"; then
    pass "detects short-message duplicates"
else
    fail "missed short-message duplicate"
fi

echo ""
echo "=== Dedup with --yes logs warning ==="
output=$(bash "$GIT_MEM" add --yes "[dri][cosmosdb] RU exhaustion container ceiling autoscale limit" 2>&1)
if echo "$output" | grep -qi "yes mode"; then
    pass "--yes mode noted in output"
else
    fail "--yes mode not mentioned"
fi

echo ""
echo "=== Empty store (no dupes possible) ==="
EMPTY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-empty-XXXXXX")
bash "$GIT_MEM" init >/dev/null 2>&1
GIT_MEMORY_DIR_ORIG="$GIT_MEMORY_DIR"
export GIT_MEMORY_DIR="$EMPTY_DIR"
git init "$EMPTY_DIR" >/dev/null 2>&1
output=$(bash "$GIT_MEM" add --yes "[test] First ever memory in empty store" 2>&1)
if echo "$output" | grep -qi "duplicate"; then
    fail "false positive in empty store"
else
    pass "no false positive in empty store"
fi
rm -rf "$EMPTY_DIR"
export GIT_MEMORY_DIR="$GIT_MEMORY_DIR_ORIG"

# --- Summary ---
echo ""
echo "================================"
echo "  Passed: $PASS   Failed: $FAIL"
echo "================================"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
