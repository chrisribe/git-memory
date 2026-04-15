#!/usr/bin/env bash
# test-search.sh — search tests for git-mem (OR, AND, case-insensitive)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-utils.sh"

export GIT_MEMORY_DIR
GIT_MEMORY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-search-XXXXXX")
cleanup() { rm -rf "$GIT_MEMORY_DIR"; }
trap cleanup EXIT

# --- Setup: seed memories ---
bash "$GIT_MEM" init >/dev/null 2>&1
bash "$GIT_MEM" add --yes "[dri][cosmosdb] RU exhaustion is container ceiling not hot partition"
bash "$GIT_MEM" add --yes "[dri][kubernetes] Pod restarts from OOM check memory limits"
bash "$GIT_MEM" add --yes "[gotcha][cosmosdb] Cross-partition queries bypass indexing policy"
bash "$GIT_MEM" add --yes "[arch][rpaas] Service mesh sidecar adds 50ms latency baseline"
bash "$GIT_MEM" add --yes "[workflow][git] Always rebase before pushing feature branches"
bash "$GIT_MEM" add --yes "[dri][cosmosdb] 408 timeout from bulk executor thread starvation" "ThreadPool.SetMinThreads(100,100) fixes the 408s in bulk import scenarios."

echo "=== OR search (default) ==="

# Single keyword
output=$(bash "$GIT_MEM" search cosmosdb 2>&1)
matches=$(echo "$output" | grep -c "cosmosdb\|RU exhaustion\|Cross-partition\|408 timeout" || true)
if [[ $matches -ge 3 ]]; then pass "single keyword finds 3 cosmosdb memories"; else fail "single keyword: expected 3+, got $matches"; fi

# Multiple keywords (OR = union)
output=$(bash "$GIT_MEM" search cosmosdb kubernetes 2>&1)
matches=$(echo "$output" | grep -ci "cosmosdb\|kubernetes\|OOM\|RU exhaustion\|partition\|408" || true)
if [[ $matches -ge 4 ]]; then pass "OR search finds cosmosdb + kubernetes"; else fail "OR search: expected 4+, got $matches"; fi

echo ""
echo "=== AND search ==="

# +cosmosdb +partition — should match memories with BOTH words
output=$(bash "$GIT_MEM" search +cosmosdb +partition 2>&1)
if echo "$output" | grep -qi "partition"; then pass "AND finds cosmosdb+partition"; else fail "AND missed cosmosdb+partition"; fi
if echo "$output" | grep -qi "kubernetes"; then fail "AND included non-matching result"; else pass "AND excludes non-matching"; fi

# +cosmosdb +timeout — should find the 408 memory (body match)
output=$(bash "$GIT_MEM" search +cosmosdb +timeout 2>&1)
if echo "$output" | grep -qi "408"; then pass "AND finds match in subject+body"; else fail "AND missed body match"; fi

# AND with no results
output=$(bash "$GIT_MEM" search +cosmosdb +kubernetes 2>&1)
if echo "$output" | grep -qi "No results"; then pass "AND returns empty for unrelated terms"; else fail "AND should have no results for cosmosdb+kubernetes"; fi

echo ""
echo "=== Case insensitivity ==="

output=$(bash "$GIT_MEM" search COSMOSDB 2>&1)
if echo "$output" | grep -qi "cosmosdb"; then pass "search is case-insensitive (upper)"; else fail "case-insensitive search failed (upper)"; fi

output=$(bash "$GIT_MEM" search CosmosDB 2>&1)
if echo "$output" | grep -qi "cosmosdb"; then pass "search is case-insensitive (mixed)"; else fail "case-insensitive search failed (mixed)"; fi

echo ""
echo "=== Tag search ==="

output=$(bash "$GIT_MEM" search "[dri]" 2>&1)
dri_count=$(echo "$output" | grep -c "dri" || true)
if [[ $dri_count -ge 3 ]]; then pass "tag search finds [dri] memories"; else fail "tag search: expected 3+ [dri], got $dri_count"; fi

echo ""
echo "=== No results ==="

output=$(bash "$GIT_MEM" search zzzyyyxxx 2>&1)
if echo "$output" | grep -qi "No results"; then pass "no results for gibberish"; else fail "should show no results for gibberish"; fi

echo ""
echo "=== OR deduplication ==="

# Searching for "cosmosdb cosmosdb" should not return duplicates
output=$(bash "$GIT_MEM" search cosmosdb cosmosdb 2>&1)
# Count lines with hashes (deduplicated results)
result_lines=$(echo "$output" | grep -cE "^  " || true)
unique_memories=3  # we have 3 cosmosdb memories
if [[ $result_lines -le $((unique_memories + 1)) ]]; then
    pass "OR deduplicates repeated terms"
else
    fail "OR returned duplicates: $result_lines lines for $unique_memories memories"
fi

echo ""
echo "=== Empty search ==="
output=$(bash "$GIT_MEM" search 2>&1) || true
if echo "$output" | grep -qi "usage\|error"; then pass "empty search shows error"; else fail "empty search should error"; fi

print_summary
