#!/usr/bin/env bash
# test-forget.sh — tests for forget & resurface commands
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-utils.sh"

export GIT_MEMORY_DIR
GIT_MEMORY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-test-XXXXXX")
cleanup() { rm -rf "$GIT_MEMORY_DIR"; }
trap cleanup EXIT

# --- Setup: init store and add some memories ---
bash "$GIT_MEM" init >/dev/null 2>&1
bash "$GIT_MEM" add --yes "[test] First memory to keep" >/dev/null 2>&1
bash "$GIT_MEM" add --yes "[test][cosmosdb] RU exhaustion means ceiling hit" >/dev/null 2>&1
bash "$GIT_MEM" add --yes "[test] Third memory to keep" >/dev/null 2>&1

# Get hash of the cosmosdb memory (the one we'll retract)
COSMOS_HASH=$(git -C "$GIT_MEMORY_DIR" log --oneline --grep="RU exhaustion" | head -1 | awk '{print $1}')

# --- Tests ---

echo "=== forget: basic ==="
assert_exit_0 "forget a memory" bash "$GIT_MEM" forget "$COSMOS_HASH"

# Add another to test with reason
bash "$GIT_MEM" add --yes "[test][cert] Certificate pinning gotcha" >/dev/null 2>&1
CERT_HASH=$(git -C "$GIT_MEMORY_DIR" log --oneline --grep="Certificate pinning" | head -1 | awk '{print $1}')

echo ""
echo "=== forget: with reason ==="
assert_exit_0 "forget with reason" bash "$GIT_MEM" forget "$CERT_HASH" --reason "superseded by new finding"

# Verify retraction commit has the reason in the body
retract_body=$(git -C "$GIT_MEMORY_DIR" log -1 --format="%b")
if echo "$retract_body" | grep -q "Reason: superseded"; then pass "reason stored in body"; else fail "reason not found in body"; fi
if echo "$retract_body" | grep -q "Retracted:"; then pass "original hash in body"; else fail "original hash not in body"; fi

echo ""
echo "=== forget: error cases ==="
assert_exit_nonzero "forget without hash" bash "$GIT_MEM" forget
assert_exit_nonzero "forget invalid hash" bash "$GIT_MEM" forget "deadbeef999999"
assert_exit_nonzero "forget already-retracted" bash "$GIT_MEM" forget "$CERT_HASH"

echo ""
echo "=== forget: excluded from search ==="
assert_output_not_contains "search excludes retracted (cosmosdb)" "RU exhaustion" bash "$GIT_MEM" search cosmosdb
assert_output_not_contains "search excludes retracted (cert)" "Certificate" bash "$GIT_MEM" search certificate
search_output=$(bash "$GIT_MEM" search memory 2>&1) || true
if echo "$search_output" | grep -Fqi "First memory"; then pass "search still finds non-retracted"; else fail "search still finds non-retracted (expected 'First memory')"; fi
if echo "$search_output" | grep -Fqi "Third memory"; then pass "search still finds non-retracted (third)"; else fail "search still finds non-retracted (expected 'Third memory')"; fi

echo ""
echo "=== forget: excluded from recent ==="
assert_output_not_contains "recent excludes retracted" "RU exhaustion" bash "$GIT_MEM" recent
assert_output_not_contains "recent excludes retraction commits" "[retracted]" bash "$GIT_MEM" recent
assert_output_contains "recent still shows non-retracted" "First memory" bash "$GIT_MEM" recent

echo ""
echo "=== forget: excluded from JSON search ==="
json_output=$(bash "$GIT_MEM" search --json cosmosdb 2>/dev/null) || true
if [[ "$json_output" == "[]" ]]; then pass "JSON search excludes retracted"; else fail "JSON search shows retracted: $json_output"; fi

echo ""
echo "=== resurface: list retracted ==="
assert_output_contains "resurface shows retracted memories" "RU exhaustion" bash "$GIT_MEM" resurface
assert_output_contains "resurface shows cert memory" "Certificate" bash "$GIT_MEM" resurface

echo ""
echo "=== resurface: search retracted ==="
assert_output_contains "resurface search finds match" "RU exhaustion" bash "$GIT_MEM" resurface cosmosdb
assert_output_not_contains "resurface search filters non-match" "Certificate" bash "$GIT_MEM" resurface cosmosdb

echo ""
echo "=== resurface: JSON output ==="
json_resurface=$(bash "$GIT_MEM" resurface --json 2>/dev/null) || true
if echo "$json_resurface" | grep -q '"retracted":true'; then pass "resurface JSON has retracted flag"; else fail "resurface JSON missing retracted flag"; fi

echo ""
echo "=== resurface: restore ==="
assert_exit_0 "restore a retracted memory" bash "$GIT_MEM" resurface --restore "$COSMOS_HASH"

# After restore, it should appear in normal search again
assert_output_contains "search finds restored memory" "RU exhaustion" bash "$GIT_MEM" search cosmosdb

# And disappear from resurface
assert_output_not_contains "resurface excludes restored" "RU exhaustion" bash "$GIT_MEM" resurface cosmosdb

echo ""
echo "=== resurface: restore error cases ==="
assert_exit_nonzero "restore without hash" bash "$GIT_MEM" resurface --restore
assert_exit_nonzero "restore non-retracted memory" bash "$GIT_MEM" resurface --restore "$COSMOS_HASH"

echo ""
echo "=== resurface: no retracted ==="
# Restore the cert one too so nothing is retracted
assert_exit_0 "restore cert memory" bash "$GIT_MEM" resurface --restore "$CERT_HASH"
assert_output_contains "resurface shows nothing when all restored" "No retracted" bash "$GIT_MEM" resurface

echo ""
echo "=== forget: re-retract after restore ==="
assert_exit_0 "re-retract a restored memory" bash "$GIT_MEM" forget "$COSMOS_HASH"
assert_output_not_contains "search excludes re-retracted" "RU exhaustion" bash "$GIT_MEM" search cosmosdb
assert_output_contains "resurface shows re-retracted" "RU exhaustion" bash "$GIT_MEM" resurface

print_summary
