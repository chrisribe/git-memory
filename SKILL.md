---
name: git-memory
description: "Zero-dependency persistent memory using git empty commits. Use when the user wants to remember information across sessions, store learnings, save context for later, or build a personal knowledge base. Also use when: 'remember this', 'save for later', 'don't forget', memory store, knowledge persistence, or any request to preserve information beyond the current conversation. Use even when the user doesn't say 'memory' explicitly — any desire to retain knowledge across sessions qualifies. Works offline, syncs via git, requires only git CLI."
user-invocable: true
---

# git-memory

Persistent memory for AI agents via git empty commits.

## Setup

Always use the `git-mem` CLI wrapper — it handles dedup detection, tag normalization, and consistent formatting.

```bash
git-mem init   # first time only — creates ~/memory-store
```

Store location: `~/memory-store` (override with `GIT_MEMORY_DIR`).

## Commands

### Store

```bash
git-mem add "[tags] summary"                          # one-liner
git-mem add "[tags] summary" "Single-line body."      # with body (single line only)
git-mem add --yes "[auto][tags] summary"              # non-interactive (agent use)
echo "Multi-line body here." | git-mem add --yes --stdin "[tags] summary"  # multi-line safe
```

> **Multi-line bodies:** Always use `--stdin` with a pipe for bodies containing newlines. The positional body argument is truncated at the first newline on Windows due to `.cmd` argument passing limitations.

### Search

Default to AND search — OR gets noisy with 2+ terms because it matches any word.

```bash
git-mem search +cosmosdb +partition    # AND: all words must match
git-mem search cosmosdb throttle       # OR: any word matches
```

### Data quality check

When retrieving memories, watch for **truncation signals** — bodies that were silently clipped:

- Body ends with `:` (introducing a list that got cut off)
- Body is a single line when the subject implies detailed content (e.g., "full recipe", "complete checklist", "architecture")
- Body ends mid-sentence or mid-word

If you detect truncation, **tell the user** instead of silently working with partial data:

> "⚠️ This memory appears truncated (body ends with `:`). Want me to search sessions or the codebase for the full context?"

### Other commands

```bash
git-mem recent 20     # browse recent (run at session start for context)
git-mem show <hash>   # full memory content
git-mem forget <hash>               # retract a memory (append-only, reversible)
git-mem forget <hash> --reason "…"  # retract with reason
git-mem resurface                   # list retracted memories
git-mem resurface cosmosdb          # search retracted memories
git-mem resurface --restore <hash>  # restore a retracted memory
git-mem tags          # list all tags
git-mem stats         # store statistics
git-mem sync          # push/pull across machines
git-mem export        # export all memories
```

## Connect an existing memories repo

Pass the remote URL to `init` — it clones the repo directly:

```bash
git-mem init https://github.com/you/memories.git
```

If you already ran `git-mem init` without a URL and want to start over:

```bash
rm -rf ~/memory-store
git-mem init https://github.com/you/memories.git
```

## Fallback: raw git (only if git-mem is not on PATH)

Only use these if `git-mem` is genuinely unavailable (e.g., not installed). Prefer `git-mem` — it adds dedup checks and tag normalization that raw git lacks.

```bash
git -C ~/memory-store commit --allow-empty -m "[tags] summary"   # store
git -C ~/memory-store log --oneline -i --grep "keyword"          # search
git -C ~/memory-store log --oneline -20                          # recent
git -C ~/memory-store log -1 --format="%B" <hash>                # show
git -C ~/memory-store pull --rebase --autostash && git -C ~/memory-store push  # sync
```

## Subject line format

The subject is what appears in search results, so it must stand alone — a vague subject means the memory is effectively lost.

```
[tags] Keyword-rich summary that stands alone
```

```
Good:  [dri][cosmosdb] RU exhaustion ≠ hot partition — check autoscale ceiling
Bad:   [dri] Investigation notes
```

## Tags

Format: `[area][subtopic] Summary`. Combine freely. Auto-normalized to lowercase.

| Tag | Purpose |
|-----|---------|
| `[dri]` | On-call / incident learnings |
| `[arch]` | Architecture decisions |
| `[gotcha]` | Non-obvious traps |
| `[workflow]` | Process / tooling patterns |
| `[decision]` | Tech choices with rationale |
| `[auto]` | AI auto-captured |

## What to save vs skip

The quality gate: "Would this save future-me 10+ minutes of investigation?" This filters out the ~80% of potential memories that are noise.

**Save** — corrections to wrong mental models, non-obvious gotchas, architecture decisions with rationale, DRI root causes, API quirks not in docs, cost/perf numbers

**Skip** — anything already in docs/on disk, ephemeral content (playlists, brainstorms, one-time plans), WIP snapshots (save conclusions not journeys), things that change soon, preferences already in user profile

### Auto-capture (`[auto]` tag)

Apply a higher bar because historically 80% of auto-captures were noise. Only auto-save when:
- User corrected a wrong assumption
- A multi-step debugging session reached resolution
- A non-obvious gotcha was discovered

If unsure, don't save — the user can always say "remember this."

## When to forget

Memories are never truly deleted — `forget` appends a retraction commit. The original is hidden from search/recent but still exists in git history. `resurface --restore` brings it back.

**Forget** — superseded knowledge (you learned the real answer), one-off incident context after resolution, noisy `[auto]` captures that failed the quality bar, wrong mental models you don't want polluting future searches

**Don't forget** — anything you're unsure about (use `resurface` later to review), root cause learnings even if the system changed, architecture decisions (the rationale still matters)

```bash
git-mem forget abc1234                          # retract
git-mem forget abc1234 --reason "wrong — real cause was X"
git-mem resurface                               # browse retracted pool
git-mem resurface --restore abc1234             # bring it back
```

## Session workflow

1. **Start:** `git-mem recent 20` — load context
2. **During:** Store non-obvious, reusable learnings immediately
3. **End:** Nothing needed — memories persist

## Branches as thought spaces (optional)

Use branches to separate knowledge by confidence level or scope:

| Branch pattern | Purpose | Merge to main? |
|----------------|---------|-----------------|
| `main` | Verified knowledge | — |
| `brainstorm/*` | Exploratory ideas | Cherry-pick survivors |
| `incident/*` | Incident context | Merge DRI lessons only |
| `project/*` | Project-scoped | Merge learnings, archive |

## Example

Discover RU exhaustion ≠ hot partition during CosmosDB investigation:

```bash
git-mem add "[dri][cosmosdb] RU exhaustion ≠ hot partition — check autoscale ceiling" \
  "100% normalized RU can mean container-level ceiling hit, not partition hotspot. Fix: increase autoScaleMaxThroughput in Bicep, not partition key redesign."
```

Later, user hits CosmosDB 408s:
```bash
git-mem search +cosmosdb
git-mem show <hash>
```
