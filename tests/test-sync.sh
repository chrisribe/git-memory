#!/usr/bin/env bash
# test-sync.sh — sync tests for git-mem (two-repo simulation)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-utils.sh"

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-sync-XXXXXX")
BARE_REPO="$TEST_ROOT/remote.git"
MACHINE_A="$TEST_ROOT/machine-a"
MACHINE_B="$TEST_ROOT/machine-b"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

# --- Setup: bare remote + two clones ---

echo "=== Setup ==="

# Create bare remote
git init --bare "$BARE_REPO" >/dev/null 2>&1
pass "bare remote created"

# Machine A: init + add remote
export GIT_MEMORY_DIR="$MACHINE_A"
bash "$GIT_MEM" init >/dev/null 2>&1
git -C "$MACHINE_A" remote add origin "$BARE_REPO"
bash "$GIT_MEM" add --yes "[test] Memory from machine A"
# Push whatever branch was created (main or master)
BRANCH=$(git -C "$MACHINE_A" rev-parse --abbrev-ref HEAD)
git -C "$MACHINE_A" push -u origin "$BRANCH" >/dev/null 2>&1
pass "machine A: init + push (branch: $BRANCH)"

# Machine B: clone from remote
git clone "$BARE_REPO" "$MACHINE_B" >/dev/null 2>&1
count_b=$(git -C "$MACHINE_B" log --oneline | wc -l | tr -d ' ')
if [[ "$count_b" -eq 1 ]]; then pass "machine B: cloned with 1 memory"; else fail "machine B: expected 1 memory, got $count_b"; fi

echo ""
echo "=== Sync: A adds, B pulls ==="

# A adds a memory
export GIT_MEMORY_DIR="$MACHINE_A"
bash "$GIT_MEM" add --yes "[test] Second memory from A"
git -C "$MACHINE_A" push >/dev/null 2>&1

# B syncs
export GIT_MEMORY_DIR="$MACHINE_B"
bash "$GIT_MEM" sync >/dev/null 2>&1 || true
count_b=$(git -C "$MACHINE_B" log --oneline | wc -l | tr -d ' ')
if [[ "$count_b" -eq 2 ]]; then pass "B synced: has 2 memories"; else fail "B sync: expected 2, got $count_b"; fi

echo ""
echo "=== Sync: both add, then sync (divergent history) ==="

# A adds
export GIT_MEMORY_DIR="$MACHINE_A"
bash "$GIT_MEM" add --yes "[test] Third memory from A only"

# B adds (divergent)
export GIT_MEMORY_DIR="$MACHINE_B"
bash "$GIT_MEM" add --yes "[test] A memory from B only"

# A pushes first
git -C "$MACHINE_A" push >/dev/null 2>&1

# B syncs (pull --rebase should handle divergence)
export GIT_MEMORY_DIR="$MACHINE_B"
if bash "$GIT_MEM" sync >/dev/null 2>&1; then
    pass "B sync succeeds after divergent commits"
else
    fail "B sync failed on divergent history"
fi

# Verify both machines have all memories
count_a=$(git -C "$MACHINE_A" log --oneline | wc -l | tr -d ' ')
# A needs to pull B's memory too
export GIT_MEMORY_DIR="$MACHINE_A"
bash "$GIT_MEM" sync >/dev/null 2>&1 || true
count_a=$(git -C "$MACHINE_A" log --oneline | wc -l | tr -d ' ')
count_b=$(git -C "$MACHINE_B" log --oneline | wc -l | tr -d ' ')

if [[ "$count_a" -eq "$count_b" ]]; then
    pass "both machines converged ($count_a memories each)"
else
    fail "divergence: A has $count_a, B has $count_b"
fi

echo ""
echo "=== No data loss ==="

# Check that all original subjects survive (search full messages, not just oneline)
for keyword in "machine A" "Second memory" "Third memory" "from B only"; do
    if git -C "$MACHINE_A" log --format="%s" | grep -qi "$keyword"; then
        pass "found: $keyword"
    else
        fail "missing: $keyword"
    fi
done

echo ""
echo "=== Sync without remote ==="
NO_REMOTE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-noremote-XXXXXX")
export GIT_MEMORY_DIR="$NO_REMOTE_DIR"
bash "$GIT_MEM" init >/dev/null 2>&1
if bash "$GIT_MEM" sync >/dev/null 2>&1; then
    fail "sync should fail without remote"
else
    pass "sync fails gracefully without remote"
fi
rm -rf "$NO_REMOTE_DIR"

print_summary
