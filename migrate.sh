#!/usr/bin/env bash
# migrate.sh — import simple-memory JSON export into a git-memory store
# Preserves original timestamps. Replays each memory as an empty commit.
#
# Usage:
#   bash migrate.sh <export.json> [target-dir]
#
# Defaults:
#   target-dir: ~/memory-test   (isolated from live store)
#
# Dependencies: bash, git, python3 (for JSON parsing)

set -euo pipefail

INPUT="${1:-}"
TARGET_DIR="${2:-$HOME/memory-test}"

[[ -z "$INPUT" ]] && { echo "Usage: $0 <export.json> [target-dir]"; exit 1; }
[[ ! -f "$INPUT" ]] && { echo "error: file not found: $INPUT"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 required for JSON parsing"; exit 1; }

# --- Init target store ---
if [[ ! -d "$TARGET_DIR/.git" ]]; then
    mkdir -p "$TARGET_DIR"
    git init "$TARGET_DIR"
    echo "Initialized: $TARGET_DIR"
else
    echo "Using existing store: $TARGET_DIR"
fi

# --- Parse and replay via python3 ---
python3 - "$INPUT" "$TARGET_DIR" <<'PYEOF'
import sys
import json
import subprocess
import os
import re

input_file = sys.argv[1]
target_dir = sys.argv[2]

with open(input_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

memories = data.get('memories', [])
total = len(memories)

# Replay oldest-first (preserve chronological order in git log)
memories_sorted = sorted(memories, key=lambda m: m.get('createdAt', ''))

ok = 0
skip = 0
err = 0

for i, mem in enumerate(memories_sorted):
    content = mem.get('content', '').strip()
    tags = mem.get('tags', [])
    created_at = mem.get('createdAt', '')

    if not content:
        skip += 1
        continue

    # Build subject: first non-empty line of content, stripped of markdown heading #
    lines = content.splitlines()
    subject_raw = ''
    body_lines = []
    for j, line in enumerate(lines):
        stripped = line.strip().lstrip('#').strip()
        if stripped:
            subject_raw = stripped
            body_lines = lines[j+1:]
            break

    # Truncate subject to 120 chars
    if len(subject_raw) > 120:
        subject_raw = subject_raw[:117] + '...'

    # Format tags as [tag1][tag2]
    tag_str = ''.join(f'[{t.lower()}]' for t in sorted(tags)) if tags else ''
    subject = f"{tag_str} {subject_raw}".strip()

    # Body: remaining content after subject line
    body = '\n'.join(body_lines).strip()

    # Set commit env for timestamp preservation
    env = os.environ.copy()
    env['GIT_AUTHOR_DATE'] = created_at
    env['GIT_COMMITTER_DATE'] = created_at

    # Build commit command
    cmd = ['git', '-C', target_dir, 'commit', '--allow-empty', '-m', subject]
    if body:
        cmd += ['-m', body]

    try:
        subprocess.run(cmd, env=env, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        ok += 1
    except subprocess.CalledProcessError as e:
        err += 1
        print(f"  error on memory {i+1}: {subject[:60]}", file=sys.stderr)

    # Progress every 50
    if (i + 1) % 50 == 0:
        print(f"  {i+1}/{total} processed...")

print(f"\nDone: {ok} imported, {skip} skipped (empty), {err} errors")
PYEOF

echo ""
echo "Migration complete → $TARGET_DIR"
echo ""
echo "Try it:"
echo "  GIT_MEMORY_DIR=$TARGET_DIR git-mem recent 20"
echo "  GIT_MEMORY_DIR=$TARGET_DIR git-mem stats"
echo "  GIT_MEMORY_DIR=$TARGET_DIR git-mem tags"
