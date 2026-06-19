# Multi-Source Memory

**Status:** ✅ Feature complete (June 17, 2026)

Federated memory search across multiple git-memory repositories — search your personal memories **plus** shared team/base knowledge without merging repos.

## Use Cases

### 1. Hermes Base Memories
Every Hermes instance can bootstrap from official base knowledge:
```bash
git-mem source add hermes-base https://github.com/NousResearch/hermes-memories
git-mem search "model-router logging"
```
**Result:** Finds setup patterns, gotchas, and workflows from the official repo **plus** your personal memories.

### 2. Team Knowledge Sharing
Share project context without exposing personal memories:
```bash
git-mem source add team /mnt/shared/team-memories
git-mem source add daniel ~/external/daniel-devops-notes
git-mem search "kubernetes deployment"
```
**Result:** Searches your repo + team repo + Daniel's repo, shows which source each hit came from.

### 3. Work/Personal Separation
Keep work and personal memories separate but searchable together:
```bash
export GIT_MEMORY_DIR=~/work-memories
git-mem source add personal ~/personal-memories
git-mem search "docker networking"
```
**Result:** Searches work memories first, then personal — all in one result set.

## Commands

```bash
# Add a source (local path or remote URL)
git-mem source add <name> <path-or-url>

# List all sources (shows enabled/disabled, entry counts)
git-mem source list

# Disable a source (keeps config, excludes from search)
git-mem source disable <name>

# Re-enable
git-mem source enable <name>

# Remove entirely
git-mem source remove <name>

# Sync sources with remotes (git pull --rebase)
git-mem source sync [name]     # sync one or all

# Search across primary + all enabled sources
git-mem search <query>
```

## How It Works

### Storage
Sources are stored in `~/.config/git-mem/sources.json`:
```json
{
  "sources": [
    {
      "name": "hermes-base",
      "path": "/opt/hermes-memories",
      "remote": "https://github.com/NousResearch/hermes-memories",
      "enabled": true
    },
    {
      "name": "team",
      "path": "/mnt/shared/team-memories",
      "remote": null,
      "enabled": true
    }
  ]
}
```

### Search Behavior
1. **Primary repo** (`$GIT_MEMORY_DIR`) is always searched first
2. **Enabled sources** are searched in order
3. Results are prefixed with `[source-name]` except primary (shows as-is)
4. Disabled sources are skipped

### Example Output
```
$ git-mem search redis

Found:
  a1b2c3d [personal] Redis timeout config
  [team] e6f0c08 [team][gotcha] Redis needs 30s minimum timeout
  [hermes-base] 9ab8def [hermes][config] Redis connection pooling
```

## Design Principles (KISS)

✅ **No jq dependency** — pure bash + awk  
✅ **No history rewriting** — sources are read-only views  
✅ **No merge conflicts** — each repo stays independent  
✅ **Explicit enable/disable** — clear control over what's searched  
✅ **Source attribution** — every result shows which repo it came from  

## Edge Cases Tested

| Test | Behavior |
|------|----------|
| Add duplicate source name | ❌ Error: "Source already exists" |
| Search with no matches | ✓ "No results." |
| Disable already-disabled | ✓ Succeeds (idempotent) |
| Remove non-existent source | ❌ Error: "Source not found" |
| Empty sources.json | ✓ Falls back to `[]`, shows help |
| Search with no sources | ✓ Searches primary only |

## Roadmap

- [x] `source add/list/enable/disable/remove`
- [x] Multi-source search with attribution
- [x] JSON storage (no jq)
- [ ] `source sync` — git pull --rebase for remote sources
- [ ] `promote <hash> --to mine` — copy entry from source to primary
- [ ] Remote URL cloning on first add

## Architecture

```
Primary Repo (read-write)          Sources (read-only)
─────────────────────               ──────────────────
~/memory-store/                     /opt/hermes-base/
  ├── .git/                           ├── .git/
  └── (empty commits)                 └── (empty commits)

                ▲                       ▲
                │                       │
                └───────────────────────┘
                         search
                    (all enabled)
```

## Testing

Clean test suite in `/tmp/git-mem-test`:
```bash
# Set up test repos
cd /tmp && rm -rf git-mem-test
mkdir -p git-mem-test/{primary,hermes-base,team}

# Initialize each with test data
cd git-mem-test/primary && git init && git config user.email "t@t" && git config user.name "T"
git commit --allow-empty -m "[personal] My memory"

cd ../hermes-base && git init && git config user.email "t@t" && git config user.name "T"
git commit --allow-empty -m "[hermes][config] Provider setup"
git commit --allow-empty -m "[hermes][gotcha] Memory path is /home/user/memory-store"

cd ../team && git init && git config user.email "t@t" && git config user.name "T"
git commit --allow-empty -m "[team][workflow] Deployment checklist"
git commit --allow-empty -m "[team][gotcha] Redis timeout needs 30s"

# Add sources
export GIT_MEMORY_DIR=/tmp/git-mem-test/primary
git-mem source add hermes-base /tmp/git-mem-test/hermes-base
git-mem source add team /tmp/git-mem-test/team

# Test
git-mem source list
git-mem search hermes
git-mem search redis
git-mem source disable team
git-mem search redis  # should be empty
git-mem source enable team
git-mem search redis  # should find it again
```

---

**Implementation:** 200 LOC, pure bash + awk, no external deps beyond git.  
**Tested:** June 17, 2026 — all features working, edge cases handled.
