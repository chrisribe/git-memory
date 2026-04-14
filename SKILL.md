---
name: git-memory
description: Zero-dependency persistent memory using git empty commits. Use when the user wants to remember information across sessions, store learnings, save context for later, or build a personal knowledge base. Also use when: "remember this", "save for later", "don't forget", memory store, knowledge persistence, or any request to preserve information beyond the current conversation. Works offline, syncs via git, requires only git CLI — no MCP server, no Node.js, no database.
---

# git-memory

Zero-dependency persistent memory for AI agents using git empty commits.

## When to use this skill

- You need to remember information across sessions
- You're working in an environment with `git` available
- You want memories that work offline, sync via git push/pull, and have version history

## Prerequisites

The `git-mem` wrapper should be on `$PATH`. If not, fall back to raw git commands (see Fallback section).

## Memory store location

Default: `~/memory-store` (override with `GIT_MEMORY_DIR` env var).

If the store doesn't exist yet:
```bash
git-mem init
```

## Commands

### Store a memory

One-liner:
```bash
git-mem add "[tags] summary"
```

With body (subject + detail):
```bash
git-mem add "[tags] summary" "Detail line 1. Detail line 2."
```

Multi-line via editor (best for complex memories):
```bash
git-mem edit
```

**Non-interactive mode** (for scripted/agent use — skips dedup prompt):
```bash
git-mem add --yes "[auto][tags] summary"
```

### Search memories

**Use AND search by default for precision.** OR search returns every memory containing any word, which gets noisy fast.

AND — all words must match (recommended for most queries):
```bash
git-mem search +cosmosdb +partition
git-mem search +dri +incident
git-mem search +certificate +deid
```

OR — any word matches (use when casting a wide net):
```bash
git-mem search cosmosdb throttle
```

**Rule of thumb:**
- 1 word → OR is fine
- 2+ words → prefer AND (`+word`) unless explicitly exploring broadly

### Browse recent context

Run at session start to load context:
```bash
git-mem recent 20
```

### Show full memory

```bash
git-mem show <hash>
```

### List tags

```bash
git-mem tags
```

### Stats

```bash
git-mem stats
```

### Sync across machines

```bash
git-mem sync
```

### Export

```bash
git-mem export
```

## Fallback: raw git commands

If `git-mem` is not available, use raw git:

```bash
# Store
git -C ~/memory-store commit --allow-empty -m "[tags] summary"

# Search
git -C ~/memory-store log --oneline -i --grep "keyword"

# Browse recent
git -C ~/memory-store log --oneline -20

# Full content
git -C ~/memory-store log -1 --format="%B" <hash>

# Sync
git -C ~/memory-store pull --rebase --autostash && git -C ~/memory-store push
```

## Subject line format

The subject line is critical — it's what appears in search results.

```
[tags] Keyword-rich summary that stands alone
```

**Rules:**
- Include searchable keywords in the subject, not just the body
- The subject should make sense without reading the body
- Think: "What would I search for later?"

```
Good:  [dri][cosmosdb] RU exhaustion ≠ hot partition — check autoscale ceiling
Bad:   [dri] Investigation notes
```

## Tag convention

```
[area][subtopic] One-line summary
```

| Tag | Purpose |
|-----|---------|
| `[dri]` | On-call lessons, incident learnings |
| `[arch]` | Architecture decisions |
| `[gotcha]` | Non-obvious traps that waste time |
| `[workflow]` | Process and tooling patterns |
| `[decision]` | Tech choices with rationale |
| `[auto]` | AI auto-captured (use when storing without explicit user request) |

Combine freely: `[dri][cosmosdb]`, `[gotcha][build]`, `[arch][rpaas]`

Tags are auto-normalized to lowercase by the wrapper.

## Capture heuristics

### SAVE (high value)

- Corrections to wrong mental models
- Non-obvious gotchas that wasted investigation time
- Architecture decisions and rationale
- DRI lessons and debugged root causes
- Team policies or conventions not written elsewhere
- Field mappings, API quirks, config locations not obvious from docs

### SKIP (noise)

- Setup instructions that already exist on disk or in docs
- Personal facts about colleagues
- Things easily searchable in official documentation
- Information that will change soon
- Short commands without context

### Quality gate

Ask: "Would this save future-me 10+ minutes of investigation?"
- Yes → store it
- No → skip it

## Session workflow

1. **Start:** `git-mem recent 20` — load recent context
2. **During work:** When you learn something non-obvious and reusable, store it immediately
3. **End:** No action needed — memories persist automatically

## Branches as thought spaces (optional)

```
main                    ← verified, high-confidence memories
├── brainstorm/apr2026  ← exploratory ideas, may be wrong
├── incident/eus2001    ← all context for one incident
└── project/foo         ← project-scoped, archive when done
```

| Pattern | Purpose | When to merge to main |
|---------|---------|----------------------|
| `main` | Proven knowledge | — |
| `brainstorm/*` | Half-baked ideas | Cherry-pick survivors |
| `incident/*` | Incident context dump | Merge DRI lessons only |
| `project/*` | Project-specific | Merge learnings, archive branch |

## Example

User asks about CosmosDB performance. You investigate and discover RU exhaustion ≠ hot partition.

Store it:
```bash
git-mem add "[dri][cosmosdb] RU exhaustion ≠ hot partition — check autoscale ceiling" \
  "100% normalized RU can mean container-level ceiling hit, not partition hotspot. Fix: increase autoScaleMaxThroughput in Bicep, not partition key redesign."
```

Later session, user hits CosmosDB 408s:
```bash
git-mem search cosmosdb
git-mem show <hash>
```
