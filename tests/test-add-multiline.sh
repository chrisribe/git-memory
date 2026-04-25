#!/usr/bin/env bash
# test-add-multiline.sh — tests for multi-line body storage in cmd_add
#
# Regression test for body truncation bug:
#   When git-mem add is called via the Windows .cmd wrapper (which uses %* to
#   forward args to bash), a body containing real newlines gets split by CMD
#   into multiple positional arguments. cmd_add only reads args[1], so args[2]+
#   are silently dropped — truncating the body at the first newline.
#
#   Root cause in git-mem cmd_add:
#     local body="${args[1]:-}"   ← only captures second arg; rest silently lost
#
#   Reproducer (PowerShell → .cmd → bash):
#     git-mem add "[tag] subject" "line1`nline2`nline3"
#     PowerShell `n = real newline → CMD %* splits → bash sees args[1]="line1"
#     args[2]="line2", args[3]="line3" — only args[1] is stored.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-utils.sh"

export GIT_MEMORY_DIR
GIT_MEMORY_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-mem-test-multiline-XXXXXX")
cleanup() { rm -rf "$GIT_MEMORY_DIR"; }
trap cleanup EXIT

bash "$GIT_MEM" init >/dev/null 2>&1

# ---------------------------------------------------------------------------
echo "=== multi-line body: single arg with embedded newlines ==="
# Passed as one bash argument using $'...' — this is the correct path.
# Verifies baseline behavior works when the shell doesn't split the arg.

MULTILINE_BODY=$'First line of body.\nSecond line of body.\nThird line of body.'

assert_exit_0 "add with multi-line body (single arg)" \
    bash "$GIT_MEM" add --yes "[test][multiline] Subject with multi-line body" "$MULTILINE_BODY"

stored_body=$(git -C "$GIT_MEMORY_DIR" log -1 --format="%b")

if echo "$stored_body" | grep -q "First line of body"; then
    pass "body: first line stored"
else
    fail "body: first line missing"
fi

if echo "$stored_body" | grep -q "Second line of body"; then
    pass "body: second line stored"
else
    fail "body: second line missing — TRUNCATION CONFIRMED (only args[1] captured)"
fi

if echo "$stored_body" | grep -q "Third line of body"; then
    pass "body: third line stored"
else
    fail "body: third line missing — TRUNCATION CONFIRMED (only args[1] captured)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== multi-line body: split args simulating Windows .cmd %* newline split ==="
# Simulates what happens when PowerShell passes a newline-containing string
# through git-mem.cmd (%*), which CMD splits at each newline into separate args.
# bash "$GIT_MEM" receives: args[0]=subject, args[1]="line1", args[2]="line2", args[3]="line3"
# Expected behavior: all lines should be joined into the body.
# Current behavior: only args[1] ("line1") is stored; args[2]+ are silently dropped.

assert_exit_0 "add with split args (simulated .cmd newline split)" \
    bash "$GIT_MEM" add --yes "[test][split] Subject simulating cmd split" \
    "First line of body." \
    "Second line of body." \
    "Third line of body."

stored_body=$(git -C "$GIT_MEMORY_DIR" log -1 --format="%b")

if echo "$stored_body" | grep -q "First line of body"; then
    pass "split args: first line stored"
else
    fail "split args: first line missing"
fi

if echo "$stored_body" | grep -q "Second line of body"; then
    pass "split args: second line stored"
else
    fail "split args: second line missing — BUG: args[2] silently dropped (only args[1] read)"
fi

if echo "$stored_body" | grep -q "Third line of body"; then
    pass "split args: third line stored"
else
    fail "split args: third line missing — BUG: args[3] silently dropped (only args[1] read)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== body truncation sentinel: colon-terminated first line ==="
# Reproduces the exact pattern seen in the wild:
#   stored body = "...workbook improved:"  (ends at first newline, mid-sentence)
# The body arg looked like "...improved:\n\n- bullet 1\n- bullet 2"
# After .cmd split: args[1]="...improved:", args[2]="", args[3]="- bullet 1", ...

assert_exit_0 "add body ending with colon (simulating real truncation)" \
    bash "$GIT_MEM" add --yes "[test][sentinel] CondoFinances workbook improved" \
    "1451 Brassard workbook improved:" \
    "" \
    "- Deleted empty columns" \
    "- Added data validation"

stored_body=$(git -C "$GIT_MEMORY_DIR" log -1 --format="%b")

if echo "$stored_body" | grep -q "Deleted empty columns"; then
    pass "sentinel: bullet content stored"
else
    fail "sentinel: bullet content missing — REPRODUCES truncation bug (body ends at first newline)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== body with literal backslash-n (caller responsibility, not a bug) ==="
# If caller passed body with literal \n characters (not real newlines),
# git stores them verbatim. This is expected — bash single-quotes don't
# expand escapes. The caller must use $'...' or actual newlines.
# This test documents the behavior, not a failure.

assert_exit_0 "add body with literal \\n escape sequences" \
    bash "$GIT_MEM" add --yes "[test][literal-n] Subject with literal backslash-n" \
    'Line 1\nLine 2\nLine 3'

stored_body=$(git -C "$GIT_MEMORY_DIR" log -1 --format="%b")

# Document: literal \n is stored as-is (expected, not a bug)
if echo "$stored_body" | grep -qF 'Line 1\nLine 2'; then
    pass "literal \\n: stored as-is (expected — caller must use real newlines)"
else
    pass "literal \\n: stored as real newlines (bonus)"
fi

# ---------------------------------------------------------------------------

print_summary
