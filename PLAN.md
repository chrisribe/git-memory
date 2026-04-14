# git-memory Implementation Plan

> Status: In Progress | Created: 2026-04-13

---

## What Exists Today

| Asset | Status | Notes |
|-------|--------|-------|
| [README.md](README.md) | ✅ Done | Concept, install, quick start, commands, config, comparisons |
| [SKILL.md](SKILL.md) | ✅ Done | Agent instructions, `git-mem` commands, fallback raw git, heuristics |
| [git-mem](git-mem) | ✅ Done | Bash wrapper — all Phase 1 core features |
| [install.sh](install.sh) | ✅ Done | Cross-platform installer with PATH detection |
| [tests/](tests/) | ✅ Done | 54 tests across 4 suites, all passing |

The wrapper (`git-mem`) is a single bash file, ~320 lines, covering:
- `init`, `add`, `edit`, `search`, `show`, `recent`, `tags`, `stats`, `sync`, `export`
- Tag normalization (auto-lowercase)
- Tag format validation (warns on missing/malformed tags)
- Dedup detection (word-overlap heuristic with interactive prompt)
- Fuzzy multi-keyword search (OR default, AND with `+` prefix)
- Safe sync (`pull --rebase --autostash` then `push`)

---

## What's Missing — Implementation Roadmap

### Phase 1: Make It Actually Work (ship quality)

These are bugs, edge cases, and polish needed before anyone else uses it.

#### 1.1 Cross-platform testing
- [x] Test on: Git Bash (Windows) — **54/54 tests passing**
- [ ] Test on: WSL2, macOS zsh, Ubuntu bash, Termux
- [ ] Verify `$EDITOR` fallback chain: `$EDITOR` → `$VISUAL` → `vi` → `nano`
- [ ] Verify color output degrades gracefully when piped (`| less`, `> file`)
- **Issue:** `grep -oE` behaves differently on macOS (BSD grep) vs Linux (GNU grep). Need to test `normalize_tags` regex on both.
- **Issue:** `wc -l` returns leading whitespace on macOS. Already handled with `tr -d ' '` but verify.

#### 1.2 Dedup detection improvements
- [ ] Current dedup only checks subject line (`%s`). Should also scan body (`%b`) for deeper matches.
- [ ] Threshold of 3 matching words (4+ chars) is a first guess. Needs tuning with real data.
- [ ] Performance: dedup scans ALL commits linearly. At 1000+ memories this will slow down. Consider caching or limiting scan to recent N commits.
- **Decision needed:** Should `--no-dedup` flag bypass the check for scripted/agent use?

#### 1.3 Search quality
Current search relies on `git log --grep` (case-insensitive literal match). Gaps:
- [ ] No stemming: "throttling" won't match "throttle"
- [ ] No synonym awareness: "rate limiting" won't find "throttling"
- [ ] No relevance ranking: results are in chronological order, not relevance
- **Mitigation (no extra deps):** Add a `search --body` flag that searches commit body too (currently only searches subject+body via `--grep` which does search both, but the oneline display hides body matches — users don't know *why* something matched)
- **Mitigation (no extra deps):** Highlight matched terms in output
- **Future (with deps):** Optional `fzf` integration for interactive fuzzy search: `git-mem search --interactive`

#### 1.4 Multi-line input on Windows
- [ ] Current `edit` command uses `$EDITOR` + tmpfile. Works everywhere.
- [ ] `add` with body uses two `-m` flags. Verify this produces correct `subject\n\nbody` format on Git Bash.
- [ ] Document that `add "subject" "body line 1\nline 2"` does NOT work — literal `\n` gets stored. Users must use `edit` or multiple `-m`.
- **Decision needed:** Should `add` accept stdin? e.g., `echo "body" | git-mem add "[tag] subject" -`

#### 1.5 Installation
- [x] `chmod +x git-mem` in repo
- [x] Add install instructions: copy to `~/.local/bin/` (or any `$PATH` dir)
- [x] Works as git subcommand: `git mem add ...` (auto-discovered via PATH)
- [x] One-liner install: `curl -sL <url> -o ~/.local/bin/git-mem && chmod +x`
- [x] `install.sh` with cross-platform PATH detection (Git Bash, zsh, bash)
- [x] Windows/Git Bash documented in README

---

### Phase 2: Agent Integration (the actual value prop)

The wrapper is for humans. Agents need different things.

#### 2.1 Non-interactive mode (`--yes` / `--no-input`)
- [x] `--yes` flag: skip dedup confirmation, store anyway but log the warning
- [ ] Add `--dry-run` flag: check for dupes and report, but don't store
- [ ] Add `--json` output flag: structured output for agents to parse
- **Design:**
  ```bash
  git-mem add --yes "[auto][cosmosdb] RU pattern"
  git-mem add --dry-run "[auto][cosmosdb] RU pattern"  # exits 0 if no dupe, 1 if dupe
  git-mem search --json cosmosdb  # {"results": [{"hash": "abc", "date": "...", "subject": "..."}]}
  ```

#### 2.2 Agent instruction integration
- [x] SKILL.md references `git-mem` commands with raw git fallback section
- [ ] Add a `.copilot-instructions.md` snippet that agents can include
- [ ] Add a session-start command that returns context + stats in one call:
  ```bash
  git-mem context   # outputs: recent 10 + stats + tag list — one command, one parse
  ```

#### 2.3 Auto-capture quality gate
- [ ] When an agent stores with `[auto]` tag, enforce stricter dedup (lower threshold)
- [ ] Rate limiter: warn if >5 memories stored in one session (agent might be noisy)
- [ ] Optional: `git-mem review` command that shows `[auto]` memories for human triage

---

### Phase 3: Scale & Maintenance

#### 3.1 Forget & resurface (append-only)
Memories are never truly deleted — just retracted. This is a feature, not a limitation.

- [ ] `git-mem forget <hash>` — appends a retraction commit (empty commit with `[retracted]` tag referencing the original hash). Does NOT rewrite history.
- [ ] `git-mem search` excludes retracted memories by default
- [ ] `git-mem resurface [keyword]` — searches ONLY retracted memories. "What did I dismiss that might matter now?"
- [ ] `git-mem resurface --restore <hash>` — un-retract: append a restore commit that re-activates the memory
- No other memory system has this. Retracted ideas become a second-chance pool.

**Commit format for retraction:**
```
[retracted] Original subject here

Retracted: <original-hash>
Original date: <original-date>
Reason: <optional, from --reason flag>
```

#### 3.2 Pruning / archiving
- [ ] `git-mem archive <tag>` — move all memories with tag to an archive branch
- [ ] `git-mem prune --older-than 1y --tag auto` — interactive cleanup of old auto-captured memories

#### 3.2 Dedup at scale
- [ ] At 500+ memories, linear scan gets slow. Build a local index:
  ```
  ~/memory-store/.git/mem-index   # hash|subject|tags — rebuilt on demand
  ```
- [ ] `git-mem rebuild-index` to regenerate
- [ ] Search checks index first, falls back to `git log` if index missing

#### 3.4 Merge conflict handling
- [x] `sync` uses `pull --rebase --autostash`
- [x] Tested: divergent histories on two clones sync without data loss (test-sync.sh)
- [ ] Add `sync --status` that shows ahead/behind without pushing.

**No import/migration tooling needed.** Git IS the transport. Clone the repo, fetch a remote, merge a branch — that's the whole point. If someone wants memories from another source, they write commits. We don't wrap what git already does.

---

### Phase 4: Nice-to-haves (low priority)

| Feature | Effort | Value | Notes |
|---------|--------|-------|-------|
| `fzf` interactive search | Small | Medium | Optional dep, graceful fallback |
| `git-mem resurface --random` | Small | Medium | Serendipity: show a random retracted memory |
| `git-mem relate <hash1> <hash2>` | Medium | Low | Link related memories via trailers |
| `git-mem viz` | Medium | Low | Tag frequency over time (ASCII chart) |
| Web viewer (`git log` → HTML) | Large | Medium | `git log --format` → static HTML, serve locally |
| Encryption at rest | Medium | Medium | `git-crypt` or GPG-sign commits |
| Hooks (post-commit notification) | Small | Low | `~/.memory-store/.git/hooks/post-commit` |

---

## Design Decisions (resolved)

### 1. `git-mem` is both standalone and a git subcommand
Ship as `git-mem` (no extension). Both `git-mem add` and `git mem add` work. Documented in README.

### 2. Env vars only
All config via `GIT_MEMORY_DIR` and `GIT_MEMORY_DEDUP_THRESHOLD`. No config files. Zero-config philosophy.

### 3. Single memory store
Multiple stores already work via env var override. No profiles, no aliases. YAGNI.

### 4. Append-only retraction for `forget`
Memories are never truly deleted — just retracted. Retracted memories are excluded from normal search but discoverable via `resurface`. No `--hard` option. If someone wants to nuke history, they know `git rebase -i`.

### 5. README for humans, SKILL.md for agents
No duplication. README covers concept, install, quick start, comparison tables. SKILL.md covers commands, heuristics, session workflow. README links to SKILL.md.

---

## File Structure (target)

```
git-memory/
├── git-mem              ← the wrapper script (bash, executable)
├── README.md            ← human docs: concept, install, quick start
├── SKILL.md             ← agent docs: commands, heuristics, workflow
├── PLAN.md              ← this file
├── install.sh           ← one-liner: copy to PATH, set permissions
└── tests/
    ├── test-basic.sh    ← init, add, search, show, recent
    ├── test-dedup.sh    ← dedup detection scenarios
    ├── test-search.sh   ← OR/AND search, case insensitivity
    └── test-sync.sh     ← two-repo sync simulation
```

---

## Immediate Next Steps

1. ~~Make `git-mem` executable and test locally~~ ✅ Done
2. ~~Update README.md~~ ✅ Done (install, quick start, commands, config, Windows support)
3. ~~Update SKILL.md~~ ✅ Done (git-mem commands, raw git fallback, session workflow)
4. ~~Write tests~~ ✅ Done (54 tests, 4 suites, all passing on Git Bash/Windows)
5. **First real use** — start using it for actual memories and see what breaks
6. **Phase 2** — `--dry-run`, `--json`, `git-mem context` command
7. **Phase 3** — `forget` + `resurface` (the unique feature)
