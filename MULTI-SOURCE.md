# Multi-Source Memory

**Status:** ✅ Feature complete (June 19, 2026) — folder-based design

Federated memory search across multiple git-memory repositories — search your primary memories **plus** shared team/base knowledge without merging repos.

## Use Cases

### 1. Agent Isolation
Each agent gets its own store; link others as read-only:
```bash
export GIT_MEMORY_DIR=~/hermes-memory
git-mem init
git-mem source add personal ~/memory-store   # symlink (local) or clone (URL)
```
Hermes writes to `~/hermes-memory`, searches both. Your personal store is never written to.

### 2. Team Knowledge Sharing
```bash
git-mem source add team /mnt/shared/team-memories
git-mem source add daniel ~/external/daniel-devops-notes
git-mem search "kubernetes deployment"
```
Searches your repo + team repo + Daniel's repo, shows which source each hit came from.

### 3. Work/Personal Separation
```bash
export GIT_MEMORY_DIR=~/work-memories
git-mem source add personal ~/personal-memories
git-mem search "docker networking"
```

## Commands

```bash
git-mem source add <name> <path-or-url>   # symlink local path or clone URL
git-mem source list                       # show all sources (enabled/disabled)
git-mem source disable <name>             # exclude from search (renames dir)
git-mem source enable <name>              # re-include in search
git-mem source remove <name>              # unlink symlink or delete clone
git-mem source sync [name]                # git pull for one or all sources
```

## How It Works

### Storage (folder-based)
Sources are git repos living under `${GIT_MEMORY_DIR}-sources/`:
```
~/memory-store-sources/
├── team/                    ← symlink to /mnt/shared/team-memories
├── hermes-base/             ← cloned from URL
└── daniel.disabled/         ← disabled (excluded from search)
```

No config file, no JSON. The filesystem IS the source of truth:
- Each child dir containing `.git` is a source
- Source name = folder basename
- `.disabled` suffix = excluded from search
- Local paths are symlinked; URLs are cloned

### Search Behavior
1. **Primary repo** (`$GIT_MEMORY_DIR`) is always searched first
2. **Enabled sources** are searched in folder-name order
3. Results from sources are prefixed with `[source-name]`
4. Disabled sources (`.disabled` suffix) are skipped

### Example Output
```
$ git-mem search redis
Found:
  a1b2c3d Redis timeout config
  [team] e6f0c08 [team][gotcha] Redis needs 30s minimum timeout
```

## Design Principles (KISS)

✅ **No config files** — filesystem is the source of truth
✅ **No jq dependency** — pure bash + awk
✅ **No history rewriting** — sources are read-only views
✅ **No merge conflicts** — each repo stays independent
✅ **Explicit enable/disable** — rename suffix, visible in `ls`
✅ **Source attribution** — every result shows which repo it came from

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GIT_MEMORY_DIR` | `~/memory-store` | Primary store (read-write) |
| `GIT_MEMORY_SOURCES_DIR` | `${GIT_MEMORY_DIR}-sources` | Folder of source repos (read-only search) |

## Roadmap

- [x] `source add/list/enable/disable/remove/sync`
- [x] Multi-source search with attribution
- [x] Folder-based storage (no JSON, no config files)
- [x] URL cloning + local symlink support
- [x] `--json` output with source field
- [x] 34 dedicated tests (test-source.sh)
- [ ] `promote <hash> --to <source>` — copy entry between stores

---

**Implementation:** ~80 LOC (iter_sources, source_dir_for, cmd_source), pure bash, no external deps beyond git.
**Tested:** June 19, 2026 — 127/127 tests passing across 7 suites.
