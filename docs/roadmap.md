# Roadmap

## Done

- [x] Git Bash (Windows) — 54/54 tests passing
- [x] Dedup checks subject + body, `--yes` flag for non-interactive use
- [x] `search --json` and `show --json` for agent output
- [x] `forget` / `resurface` / `resurface --restore` (append-only retraction)
- [x] `sync` with `pull --rebase --autostash`, divergent history tested

---

## Up Next

### Cross-platform testing
- [ ] WSL2, macOS zsh, Ubuntu bash, Termux
- [ ] Verify `$EDITOR` → `$VISUAL` → `vi` fallback chain
- [ ] Verify color output degrades when piped (`| less`, `> file`)
- **Known:** `grep -oE` (BSD vs GNU) and `wc -l` whitespace (macOS) — mitigations in place, need verification

### `git-mem context`
- [ ] Single command: recent 10 + stats + tag list — one call for agent session start

### `--dry-run`
- [ ] Check for dupes without storing (exit 0 = clean, 1 = dupe). Useful for CI and scripted flows.

### `sync --status`
- [ ] Show ahead/behind count without pushing

### Pruning
- [ ] `git-mem prune --older-than 1y --tag auto` — interactive cleanup of old auto-captured memories

---

## Nice-to-haves

| Feature | Effort | Notes |
|---------|--------|-------|
| `fzf` interactive search | Small | Optional dep, graceful fallback |
| Encryption at rest | Medium | `git-crypt` or GPG-signed commits |

---

## Design Decisions

### `git-mem` is both standalone and a git subcommand
Ship as `git-mem` (no extension). Both `git-mem add` and `git mem add` work via PATH discovery.

### Env vars only
All config via `GIT_MEMORY_DIR` and `GIT_MEMORY_DEDUP_THRESHOLD`. No config files. Zero-config philosophy.

### Single memory store
Multiple stores already work via env var override. No profiles, no named contexts. YAGNI.

### Append-only retraction for `forget`
Memories are never deleted — just retracted. Retracted memories are excluded from normal search but discoverable via `resurface`. No `--hard` option. Users who want to rewrite history know `git rebase -i`.

### README for humans, SKILL.md for agents
README covers concept, install, quick start, comparison tables. SKILL.md covers commands, heuristics, session workflow. No duplication.
