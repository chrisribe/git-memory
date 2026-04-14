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

---

## Install

### One-liner

```bash
curl -sL https://raw.githubusercontent.com/chrisribe/git-memory/main/git-mem \
  -o ~/.local/bin/git-mem && chmod +x ~/.local/bin/git-mem
```

### From source

```bash
git clone https://github.com/chrisribe/git-memory.git
cd git-memory
./install.sh
```

### Manual

Copy `git-mem` anywhere on your `$PATH` and make it executable:

```bash
mkdir -p ~/.local/bin
cp git-mem ~/.local/bin/git-mem
chmod +x ~/.local/bin/git-mem
```

**Windows (Git Bash):** `~/.local/bin` isn't on `$PATH` by default. Add it to your `~/.bashrc`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Verify

```bash
git-mem help     # standalone
git mem help     # as git subcommand — both work
```

> Because the script is named `git-mem`, git auto-discovers it as a subcommand. `git mem add ...` and `git-mem add ...` are interchangeable.

---

## Quick Start

```bash
# Initialize memory store
git-mem init

# Store a memory
git-mem add "[dri][cosmosdb] RU exhaustion is container ceiling not partition"

# Store with details (opens $EDITOR)
git-mem edit

# Search (OR — any word matches)
git-mem search cosmosdb throttle

# Search (AND — all words must match)
git-mem search +cosmosdb +partition

# Browse recent
git-mem recent

# See all tags
git-mem tags

# Stats
git-mem stats

# Sync across machines
git-mem sync
```

---

## Commands

| Command | What it does |
|---------|-------------|
| `git-mem init` | Initialize memory store at `~/memory-store` |
| `git-mem add "[tags] summary"` | Store a one-liner (with dedup check) |
| `git-mem add "[tags] summary" "body"` | Store with subject + body |
| `git-mem edit` | Store via `$EDITOR` (multi-line, no escaping pain) |
| `git-mem search <words>` | Fuzzy multi-keyword search (OR) |
| `git-mem search +word1 +word2` | AND search (all must match) |
| `git-mem show <hash>` | Show full memory content |
| `git-mem recent [n]` | Browse recent memories (default: 20) |
| `git-mem tags` | List all tags with frequency counts |
| `git-mem stats` | Memory store statistics |
| `git-mem sync` | Safe `pull --rebase` then `push` |
| `git-mem export` | Dump all memories to stdout |

### What the wrapper adds over raw git

| Feature | Raw git | git-mem |
|---------|---------|---------|
| Dedup detection | ❌ | ✅ Warns before storing near-duplicates |
| Tag normalization | ❌ | ✅ Auto-lowercases `[DRI]` → `[dri]` |
| Tag validation | ❌ | ✅ Warns on missing or malformed tags |
| Multi-keyword search | One `--grep` at a time | OR and AND in one command |
| Case-insensitive search | Need `-i` flag | Always on |
| Multi-line input | Shell escaping hell | `edit` opens `$EDITOR` cleanly |
| Safe sync | Manual rebase dance | One command: `git-mem sync` |

---

## Configuration

Environment variables only. Zero config files.

| Variable | Default | Purpose |
|----------|---------|---------|
| `GIT_MEMORY_DIR` | `~/memory-store` | Path to memory store repo |
| `GIT_MEMORY_DEDUP_THRESHOLD` | `3` | Min word overlap to trigger dedup warning |

```bash
# Use a different memory store
export GIT_MEMORY_DIR=~/work-memories
git-mem add "[dri] something work-related"
```

---

## Tag Convention

Tags go in square brackets at the start of the commit subject:

```
[area][subtopic] One-line summary
```

| Tag | Purpose |
|-----|---------|
| `[dri]` | On-call lessons |
| `[arch]` | Architecture decisions |
| `[gotcha]` | Non-obvious traps |
| `[workflow]` | Process/tooling |
| `[decision]` | Tech choices and rationale |
| `[auto]` | AI auto-captured |

Combine freely: `[dri][cosmosdb]`, `[gotcha][build]`, `[arch][rpaas]`

---

## Git Aliases (alternative to wrapper)

If you prefer plain git over the `git-mem` script, add these to `~/.gitconfig`:

```ini
[alias]
    remember = commit --allow-empty
    mem = "!f() { git commit --allow-empty -m \"$*\"; }; f"
    recall = log --grep --oneline
    recall-full = "!f() { git log --grep=\"$1\" --format='%C(yellow)%h%Creset %C(green)%aI%Creset%n%B%n---'; }; f"
    memories = log --oneline -20
    forget = "!f() { git rebase -i \"$1\"^; }; f"
    mem-stats = "!echo \"Total memories: $(git log --oneline | wc -l)\""
    mem-export = log --format="%H|%aI|%s%n%b%n---"
```

```bash
git mem "[dri][k8s] Pod restarts from OOM — check memory limits first"
git recall cosmosdb
git memories
```

> **Under the hood:** Every memory is just `git commit --allow-empty -m "..."`. Search is `git log --grep`. That's the entire system — no magic, no abstraction. The wrapper and aliases are convenience, not necessity.

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

## For AI Agents

See [SKILL.md](SKILL.md) for agent instructions, capture heuristics, and session workflow.

### VS Code Copilot

`install.sh` copies the skill to `~/.agents/skills/git-memory/SKILL.md` automatically. The skill triggers on memory-related requests.

### Claude Code

Once the repo is public: `/plugin marketplace add chrisribe/git-memory`

Until then, copy `SKILL.md` manually or reference it from your `CLAUDE.md`.

### Other agents (Cursor, Windsurf, etc.)

Copy `SKILL.md` to wherever your agent reads instructions. The file is plain markdown — works anywhere an agent can read a file.

---

## Compared to Plan A (GitHub Issues as memory)

| | git-memory | GitHub Issues |
|---|---|---|
| Offline | ✅ | ❌ |
| Private by default | ✅ | Requires private repo |
| No external service | ✅ | Requires GitHub up |
| CLI | `git-mem search` | `gh issue comment list` |
| Reactions/voting | ❌ | ✅ |
| Web UI | `git log` or any git GUI | GitHub web |
| Mobile access | Termux | GitHub mobile |

GitHub Issues wins on discoverability and reactions-as-quality-signal.
git-memory wins on no-network, no-service-dependency, total privacy control.

---

## Status

Working. Wrapper script (`git-mem`), installer, 54 passing tests. See [PLAN.md](PLAN.md) for roadmap.

Origin: [April 2, 2026 brain-fart session](https://github.com/chrisribe/simple-memory-mcp) exploring the simple-memory-mcp ecosystem, MCP vs skills trade-offs, and editor lock-in.
