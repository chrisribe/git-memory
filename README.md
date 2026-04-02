# git-memory

> An AI memory system where the emptiest repo is the fullest database.

**The idea:** Use git empty commits as a persistent, portable, zero-dependency memory store for AI agents. No MCP server. No Node.js. No SQLite. Just `git`.

---

## The Problem with Existing Memory Solutions

| System | Lock-in | Runtime | Failure modes |
|--------|---------|---------|--------------|
| VS Code built-in `/memories/` | VS Code only | None | None |
| simple-memory MCP | Any MCP client | Node.js server | Server crash, auth, connection |
| memory-mcp (marketplace) | Any MCP client | Node.js 22+ | Same + Git credentials |
| **git-memory** | Anything with `git` | None | Disk write |

The irony of MCP memory systems: they add a protocol layer to solve portability, but introduce server processes and runtime dependencies. `git` is already on every machine, every editor, every CI, every SAW, every phone (Termux). It needs no proxy.

---

## How It Works

The database is a git repo. Every memory is an empty commit. The repo has no files — ever.

```
memory-store/
└── .git/    ← the ENTIRE database lives here
             (no other files)
```

### Primitives

```bash
# Remember
git commit --allow-empty -m "[dri][cosmosdb] RU exhaustion ≠ hot partition.
Check container autoscale max before blaming partition key cardinality."

# Recall by keyword
git log --grep="cosmosdb" --oneline

# Recall by tag
git log --grep="\[dri\]" --oneline

# Recall by time
git log --grep="\[dri\]" --oneline --since="2 weeks ago"

# Full content of one memory
git log -1 --format="%B" abc1234

# Forget
git rebase -i HEAD~N  # drop the commit

# Export everything
git log --format="%H|%aI|%s%n%b" > dump.txt
```

### Multi-line memories

The commit subject is the summary. The body is detail:

```bash
git commit --allow-empty -m "[ev2][bicep] API version mismatch pattern

Error says '2024-09-01' but fix is in Bicep @version suffix, not EV2 config.
Grep: @2024-09-01 in infra/modules/manifest/*.bicep
Root cause: compiled ARM output vs Bicep input mismatch.
Files: provider_registration.bicep, deid_resource_type_registration.bicep"
```

---

## Git Alias Helpers

Add to `~/.gitconfig`:

```ini
[alias]
    # Remember a memory (opens editor for subject + body)
    remember = commit --allow-empty

    # Quick one-liner memory
    mem = "!f() { git commit --allow-empty -m \"$*\"; }; f"

    # Search memories
    recall = log --grep --oneline

    # Search memories with full body
    recall-full = "!f() { git log --grep=\"$1\" --format='%C(yellow)%h%Creset %C(green)%aI%Creset%n%B%n---'; }; f"

    # Browse recent memories
    memories = log --oneline -20

    # Browse all memories
    memories-all = log --oneline

    # Forget a memory by hash (destructive - rewrites history)
    forget = "!f() { git rebase -i \"$1\"^; }; f"

    # Memory stats
    mem-stats = "!echo \"Total memories: $(git log --oneline | wc -l)\""

    # Export to text
    mem-export = log --format="%H|%aI|%s%n%b%n---"
```

Usage after adding aliases:

```bash
git mem "[dri][k8s] Pod restarts from OOM — check memory limits in helm values first"
git recall cosmosdb
git recall-full ev2
git memories
git mem-stats
```

---

## Tag Convention (suggestion)

Tags go in square brackets at the start of the commit subject:

```
[area][subtopic] One-line summary

Optional multi-line detail...
```

**Example areas:**
- `[dri]` — on-call lessons
- `[arch]` — architecture decisions
- `[gotcha]` — non-obvious traps
- `[workflow]` — process/tooling
- `[decision]` — tech choices and rationale
- `[people]` — team/person context
- `[auto]` — AI auto-captured

**Combine freely:** `[dri][cosmosdb]`, `[gotcha][build]`, `[arch][rpaas]`

---

## Agent Instruction Paragraph

Drop this in your agent's instructions file or system prompt:

```
Your persistent memory is a git repo at ~/memory-store (or wherever configured).
At session start, run: git -C ~/memory-store log --oneline -20
to load recent context into your working memory.

When you learn something non-obvious that would save future sessions 10+ minutes,
run: git -C ~/memory-store commit --allow-empty -m "[tags] summary\n\nDetails"

Capture heuristics:
- SAVE: corrections to wrong mental models, non-obvious gotchas, architecture decisions,
        DRI lessons, debugged root causes, team policy
- SKIP: setup instructions that already exist on disk, personal facts, things
        easily searchable in docs, things that will change soon

To recall: git -C ~/memory-store log --grep="keyword" --oneline
```

---

## Portability

```bash
# Sync anywhere
git remote add origin git@github.com:you/memory-store.git
git push -u origin main

# Offline backup (single file)
git bundle create memory-$(date +%Y%m%d).bundle --all

# Merge memories from another machine
git fetch origin
git merge origin/main  # almost never conflicts (append-only)
```

Works on: WSL, SAW, devbox, phone (Termux), CI, bare Linux box, anywhere.

---

## Compared to Plan A (GitHub Issues as memory)

| | git-memory | GitHub Issues |
|---|---|---|
| Offline | ✅ | ❌ |
| Private by default | ✅ | Requires private repo |
| No external service | ✅ | Requires GitHub up |
| CLI | `git log --grep` | `gh issue comment list` |
| Reactions/voting | ❌ | ✅ |
| Web UI | `git log` or any git GUI | GitHub web |
| Mobile access | Termux | GitHub mobile |

GitHub Issues (Plan A) wins on discoverability and reactions-as-quality-signal.  
git-memory wins on no-network, no-service-dependency, total privacy control.

---

## Migration from simple-memory

TODO: migration script that reads simple-memory GraphQL export and replays as git commits, preserving timestamps via `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`.

```bash
# Concept
export GIT_AUTHOR_DATE="2026-02-18T22:39:03Z"
export GIT_COMMITTER_DATE="2026-02-18T22:39:03Z"
git commit --allow-empty -m "[ev2][bicep][auto] API version mismatch...
```

---

## Status

🧪 Concept / experiment. Not packaged. Not on npm. Just ideas and aliases.

Origin: [April 2, 2026 brain-fart session](https://github.com/chrisribe/simple-memory-mcp) exploring the simple-memory-mcp ecosystem,  
Agency Marketplace, MCP vs skills trade-offs, and editor lock-in.
