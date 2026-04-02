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

## Memory store location

```
~/memory-store
```

If this repo doesn't exist, create it:
```bash
git init ~/memory-store
```

## Commands

### Remember (store a memory)

Quick one-liner:
```bash
git -C ~/memory-store commit --allow-empty -m "[tags] summary"
```

With details (multi-line):
```bash
git -C ~/memory-store commit --allow-empty -m "[tags] summary

Detail line 1
Detail line 2
Code refs, links, etc."
```

**PowerShell/Windows alternative** (use multiple `-m` flags):
```bash
git -C ~/memory-store commit --allow-empty -m "[tags] summary" -m "Detail line 1" -m "Detail line 2"
```

### Recall (search memories)

By keyword:
```bash
git -C ~/memory-store log --oneline --grep "keyword"
```

By tag:
```bash
git -C ~/memory-store log --oneline --grep "\[dri\]"
```

By time:
```bash
git -C ~/memory-store log --oneline --grep "keyword" --since="2 weeks ago"
```

Full content of one memory:
```bash
git -C ~/memory-store log -1 --format="%B" <hash>
```

### Browse recent context (run at session start)

```bash
git -C ~/memory-store log --oneline -20
```

### Stats

```bash
git -C ~/memory-store log --oneline | wc -l
```

## Subject line format

The subject line (first line) is critical — it's what you see in `git log --oneline` results.

```
[tags] Keyword-rich summary that stands alone
```

**Best practices:**
- Include searchable keywords in the subject, not just the body
- The subject should make sense without reading the body
- `git log --grep` searches full content, but `--oneline` only shows the subject
- Think: "What would I search for later?"

**Example:**
```
Good:  [dri][cosmosdb] RU exhaustion ≠ hot partition — check autoscale ceiling
Bad:   [dri] Investigation notes
```

## Tag convention

Tags go in square brackets at the start of the commit subject:

```
[area][subtopic] One-line summary
```

**Common tags:**
- `[dri]` — on-call lessons, incident learnings
- `[arch]` — architecture decisions
- `[gotcha]` — non-obvious traps that waste time
- `[workflow]` — process and tooling patterns
- `[decision]` — tech choices with rationale
- `[auto]` — AI auto-captured (use when you store without explicit user request)

Combine freely: `[dri][cosmosdb]`, `[gotcha][build]`, `[arch][rpaas]`

## Capture heuristics

### SAVE these (high value)

- Corrections to wrong mental models
- Non-obvious gotchas that wasted investigation time
- Architecture decisions and rationale
- DRI lessons and debugged root causes
- Team policies or conventions not written elsewhere
- Field mappings, API quirks, or config locations that aren't obvious from docs

### SKIP these (low value / noise)

- Setup instructions that already exist on disk or in docs
- Personal facts about colleagues
- Things easily searchable in official documentation
- Information that will change soon
- Short commands without context (just a bookmark, not a memory)

### Quality signal

Ask: "Would this save future-me 10+ minutes of investigation?"
- Yes → store it
- No → skip it

## Session workflow

1. **Start of session:** Run `git -C ~/memory-store log --oneline -20` to load recent context
2. **During work:** When you learn something non-obvious and reusable, store it immediately
3. **End of session:** No action needed — memories persist automatically

## Multi-machine sync (optional)

```bash
# Add remote (once)
git -C ~/memory-store remote add origin <your-private-repo-url>

# Push after storing
git -C ~/memory-store push

# Pull on another machine
git -C ~/memory-store pull
```

## Branches as thought spaces (optional)

Use branches to separate different types of thinking:

```
main                    ← verified, high-confidence memories
├── brainstorm/apr2026  ← exploratory ideas, may be wrong
├── incident/eus2001    ← all context for one incident
└── project/foo         ← project-scoped, archive when done
```

**Branch patterns:**

| Pattern | Purpose | When to merge to main |
|---------|---------|----------------------|
| `main` | Proven knowledge | — |
| `brainstorm/*` | Half-baked ideas | Cherry-pick survivors |
| `incident/*` | Incident context dump | Merge DRI lessons only |
| `project/*` | Project-specific | Merge learnings, archive branch |

**Workflow:**

```bash
# Start exploring
git -C ~/memory-store checkout -b brainstorm/memory-systems

# Dump ideas freely (noise is okay here)
git -C ~/memory-store commit --allow-empty -m "[idea] What if commits were memories?"
git -C ~/memory-store commit --allow-empty -m "[idea] GitHub Issues as DB?"

# One idea wins — cherry-pick to main
git -C ~/memory-store checkout main
git -C ~/memory-store cherry-pick <winner-hash>

# Or squash exploration into one refined memory
git -C ~/memory-store merge --squash brainstorm/memory-systems
git -C ~/memory-store commit --allow-empty -m "[decision] Chose empty commits over GitHub Issues

Evaluated: files, Issues, empty commits.
Winner: empty commits — zero deps, offline, git everywhere."
```

**Benefits:**
- Safe space for noise — brainstorms don't pollute main
- Context grouping — incident branches keep related memories together
- Review before merge — decide what's worth keeping
- Archive, don't delete — old branches stay recoverable

## If aliases are available

The repo may have these aliases pre-configured:

| Alias | Equivalent |
|-------|------------|
| `git mem "[tags] msg"` | `git commit --allow-empty -m "[tags] msg"` |
| `git recall keyword` | `git log --oneline --grep "keyword"` |
| `git memories` | `git log --oneline -20` |
| `git mem-stats` | Count of all memories |

Use aliases when in the memory-store directory. Use full commands with `-C ~/memory-store` when invoking from elsewhere.

## Maintenance

### Remove a single memory

```bash
# Find the hash
git -C ~/memory-store log --oneline --grep "keyword"

# Interactive rebase to drop it
git -C ~/memory-store rebase -i <hash>^
# In editor: change "pick <hash>" to "drop <hash>", save and exit
```

### Remove duplicates or bulk cleanup

```bash
# Interactive rebase from root
git -C ~/memory-store rebase -i --root
# In editor: change "pick" to "drop" for unwanted commits, save and exit
```

### Nuclear option (wipe and start fresh)

```bash
cd ~/memory-store
rm -rf .git
git init
```

Or keep history but reset content:
```bash
git -C ~/memory-store checkout --orphan fresh
git -C ~/memory-store commit --allow-empty -m "Reset memory store"
git -C ~/memory-store branch -D main
git -C ~/memory-store branch -m main
```

### After cleanup

Force push if you have a remote (history was rewritten):
```bash
git -C ~/memory-store push --force-with-lease
```

## Example

User asks about CosmosDB performance. You investigate and discover RU exhaustion ≠ hot partition — it's total container ceiling.

Store it:
```bash
git -C ~/memory-store commit --allow-empty -m "[dri][cosmosdb] RU exhaustion ≠ hot partition

100% normalized RU can mean container-level ceiling hit, not partition hotspot.
With unique partition keys, load is distributed — saturation comes from aggregate volume.
Fix: increase autoScaleMaxThroughput in Bicep, not partition key redesign.
Discovered during eus2001 incident Mar 2026."
```

Later session, user hits CosmosDB 408s:
```bash
git -C ~/memory-store log --oneline --grep "cosmosdb"
# → shows the memory hash
git -C ~/memory-store log -1 --format="%B" <hash>
# → full content with the fix
```
