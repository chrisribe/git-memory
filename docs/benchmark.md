# git-memory Benchmark & Comparison

> Benchmarked April 13, 2026 on Windows / Git Bash

Validation of git-memory against simple-memory MCP — the most widely used MCP-based memory system. Tests run against a real corpus of 800+ memories migrated from simple-memory.

---

## Migration

| Metric | Result |
|--------|--------|
| Memories migrated | 800+ |
| Date range | 8 months |
| Unique tags | 1,500+ |
| Method | `git fast-import` (single process) |
| Time | **0.3s** |
| Data loss | None — all content, tags, and timestamps preserved |

The initial approach (one `git commit` subprocess per memory) ran at ~3/s. Switching to `git fast-import` achieved 2,600+/s.

---

## Search Quality

Identical queries run against both systems with comparable result limits.

| Query | simple-memory (limit:50) | git-memory OR | git-memory AND |
|-------|--------------------------|--------------|----------------|
| `cosmosdb` | 29 | 22 | — |
| `dri incident` | 30+ | noisy (broad matches) | 7 precise |
| `certificate tls` | 20+ | 9 broad | 9 precise |
| `memory mcp` | 20+ | 14 | — |

### Observations

- **simple-memory** returns relevance-ranked results. Defaults to 10; must pass `limit:50` for full recall.
- **git-memory OR** returns all matches unranked. Broad terms pull in noise.
- **git-memory AND** (`+word1 +word2`) is the precision tool. Results are clean and specific.
- **Recall quality is equivalent** when both systems are tuned (AND in git-memory, limit:50 in simple-memory).

---

## Performance at Scale (800+ memories)

| Operation | Before fixes | After fixes | Speedup |
|-----------|-------------|-------------|---------|
| AND search | 72.6s | **0.7s** | 100x |
| `add` with dedup check | hung indefinitely | **0.9s** | ∞ |
| OR search (single keyword) | 0.4s | 0.4s | — |
| OR search (rare keyword, 56 results) | 0.6s | 0.6s | — |
| Search (no results) | 0.4s | 0.4s | — |

### Root causes fixed

1. **AND search** spawned one `git log -1` subprocess per candidate commit. Fix: `git log --all-match --grep=X --grep=Y` — one process, sub-second.
2. **Dedup check** iterated all commits × all words in a nested bash loop. Fix: `git log --grep` per word + `awk` frequency counting.
3. **OR dedup** used O(n²) bash array scan. Fix: `awk '!seen[$1]++'` pipe.

---

## Agent Round-Trip

Store a memory, then search and retrieve it — the core agent workflow.

### Store

| | simple-memory MCP | git-memory |
|---|---|---|
| Mechanism | 1 MCP tool call | 1 terminal command |
| Time | instant (network-bound) | **0.8s** (local, includes dedup) |

### Search

| | simple-memory MCP | git-memory |
|---|---|---|
| Mechanism | GraphQL query | `git-mem search --json` |
| Time | instant | **0.17s** (text) / **0.28s** (JSON) |
| Output | `{"data":{"memories":[...]}}` | `[{"hash":"...","date":"...","subject":"..."}]` |

### Full content fetch

| | simple-memory MCP | git-memory |
|---|---|---|
| Mechanism | `memory(hash:"...")` | `git-mem show --json <hash>` |
| Time | instant | **0.08s** (text) / **0.27s** (JSON) |
| Output | JSON with content, tags, createdAt | JSON with hash, date, subject, body |

### Token efficiency

| | simple-memory MCP | git-memory --json |
|---|---|---|
| Search (7 results) | ~820 chars | ~1,100 chars |
| Show (full body) | ~1,450 chars (title duplicated) | ~1,100 chars (no duplication) |

---

## Cold Start

Time from zero (no install) to first memory stored and searchable.

| | simple-memory MCP | git-memory |
|---|---|---|
| Prerequisites | Node.js, npm | git, bash |
| Install steps | npm install + MCP config + VS Code restart | curl one file + chmod |
| VS Code restart | Required | Not required |
| Time to first memory | Minutes | **0.6s** |
| Works on SAW/devbox | ⚠️ Needs Node.js | ✅ git is pre-installed |
| Works in CI | Needs MCP runtime | ✅ Just bash |
| Works offline | ❌ (MCP server dependency) | ✅ |
| Works on Termux (mobile) | ⚠️ | ✅ |

---

## Unit Tests

54 tests across 4 suites, all passing.

| Suite | Tests | Coverage |
|-------|-------|----------|
| test-basic.sh | 25 | init, add, tags, stats, export, show, recent, help, errors |
| test-dedup.sh | 6 | duplicate detection, false positives, short messages, --yes mode |
| test-search.sh | 12 | OR, AND, case insensitivity, tag search, dedup, edge cases |
| test-sync.sh | 11 | remote setup, pull/push, divergent history, data loss check |

---

## Auto-Capture Quality Audit

Audited all memories tagged `[auto]` in a production simple-memory MCP store (10 memories, one week).

| Category | Count | % |
|----------|------:|--:|
| Genuinely valuable | 2 | 20% |
| Context dump (stale quickly) | 2 | 20% |
| Trivial/noise | 5 | 50% |
| Duplicate | 1 | 10% |

### Pattern

The 2 valuable auto-saves both **corrected a wrong mental model** — the kind of thing you'd want to remember. The 5 noise entries were ephemeral session activity the agent happened to observe. The heuristic doesn't distinguish "user discovered something important" from ambient activity.

### Impact on the comparison

Silent auto-capture (often cited as an MCP advantage) is actually a liability at this signal-to-noise ratio. Terminal-visible saves (git-memory) let you notice and reject noise in real time. SKILL.md auto-capture rules are tightened to require a higher bar for `[auto]` tagged saves.

---

## Where git-memory Wins

- **Zero dependencies** — works anywhere git exists
- **Offline-first** — no server, no network needed
- **Cold start** — 0.6s from nothing to first memory
- **Transparency** — every memory is a git commit, inspectable with any git tool
- **Portability** — SAW, devbox, Termux, CI, bare Linux
- **No compile/rebuild cycle** — edit SKILL.md or the bash script and you're done. MCP needs TypeScript rebuild + server restart.
- **Visible auto-capture** — terminal commands let you catch noise. Silent MCP saves accumulate junk unnoticed.
- **Dedup built-in** — warns before storing near-duplicates. MCP has none.
- **Cross-agent compatibility** — SKILL.md works in VS Code Copilot, Claude Code, Cursor, any agent that reads files. MCP only works in MCP-compatible clients.
- **No maintenance** — no server process to monitor, restart, or debug.

## Where simple-memory MCP Wins

- **Structured API** — native tool calls, no terminal parsing
- **Relevance ranking** — results scored by relevance, not just grep matches

## Where They're Equal

- Recall quality (when tuned: AND search vs limit:50)
- Token efficiency (~same chars per result)
- Full content retrieval (identical data)
- JSON output (git-memory `--json` matches MCP structured responses)

---

**Not yet tested:** failure recovery, parallel write safety, cross-platform (macOS/Linux/WSL2).
