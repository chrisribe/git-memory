#!/usr/bin/env bash
# run-all.sh — run all git-mem tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
    [[ "$(basename "$test_file")" == "test-utils.sh" ]] && continue
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Running: $(basename "$test_file")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if bash "$test_file"; then
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test suites passed: $TOTAL_PASS"
echo "  Test suites failed: $TOTAL_FAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ $TOTAL_FAIL -eq 0 ]] && exit 0 || exit 1
