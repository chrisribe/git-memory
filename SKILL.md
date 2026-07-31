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
Sources location: `~/memory-store-sources` (override with `GIT_MEMORY_SOURCES_DIR`).

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

> **Fallback:** If `git-mem` isn't installed, use `git -C ~/memory-store commit --allow-empty -m "[tags] summary"` — but you lose dedup checks and tag normalization.

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

Use `git-mem forget <hash>` to retract superseded knowledge or noisy `[auto]` captures. Don't forget architecture decisions or root causes — the rationale still matters. Retraction is reversible: `git-mem resurface --restore <hash>`.

## Session workflow

1. **Start:** `git-mem recent 20` — load context
2. **During:** Store non-obvious, reusable learnings immediately
3. **End:** Nothing needed — memories persist


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

## Multi-source (federated search)

Search your primary store **plus** additional read-only memory repos. Writes always go to the primary store only — sources are never modified.

### Commands

```bash
git-mem source add <name> <path-or-url>   # symlink local path or clone URL
git-mem source list                       # show all sources (enabled/disabled)
git-mem source disable <name>             # exclude from search (keeps repo)
git-mem source enable <name>              # re-include in search
git-mem source remove <name>              # unlink symlink or delete clone
git-mem source sync [name]                # git pull for one or all sources
```

### Use cases

- **Knowledge domains** — add curated repos: `git-mem source add sql-expert https://...`
- **Team sharing** — `git-mem source add team /shared/team-memories`
- **Isolated contexts** — agents/projects get their own `GIT_MEMORY_DIR`, link others as read-only
- **Project archival** — `git-mem source add old-project ~/archive/atlas-memories` then disable when noisy

### Environment variables

| Variable | Default | Purpose |
|----------|---------|--------|
| `GIT_MEMORY_DIR` | `~/memory-store` | Primary store (read-write) |
| `GIT_MEMORY_SOURCES_DIR` | `${GIT_MEMORY_DIR}-sources` | Folder of source repos (read-only search) |

Sources are just git repos in the sources folder. Folder name = source name. Append `.disabled` to the folder name to exclude from search.
