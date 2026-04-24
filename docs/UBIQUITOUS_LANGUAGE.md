# Ubiquitous Language

## Core Concepts

| Term | Definition | Aliases to avoid |
|------|------------|------------------|
| **Memory** | A single fact, learning, or decision stored as an empty git commit | Note, entry, commit, record |
| **Memory store** | The git repository containing all memories (default: `~/memory-store`) | Database, repo, vault |
| **Decision cache** | The conceptual role of git-memory: storing conclusions and learnings, not raw information | Search index, knowledge base, RAG |

## Memory Structure

| Term | Definition | Aliases to avoid |
|------|------------|------------------|
| **Subject** | The first line of a memory — must stand alone and be keyword-rich for search | Summary, title, message, headline |
| **Body** | Optional detail text after the subject, separated by blank line | Details, content, description |
| **Tag** | Bracketed prefix on the subject (e.g., `[dri][auto]`) for categorization | Label, category |

## Memory Lifecycle

| Term | Definition | Aliases to avoid |
|------|------------|------------------|
| **Store** | Create a new memory via `git-mem add` | Save, write, commit |
| **Forget** | Soft-delete a memory via `git-mem forget` — excluded from search but recoverable | Delete, remove, retract, archive |
| **Resurface** | Search or restore retracted memories | Undelete, recover |
| **Dedup** | Check for similar existing memories before storing | Duplicate check |
| **Sync** | Pull (rebase) then push to remote | Push, backup |

## Actors

| Term | Definition | Aliases to avoid |
|------|------------|------------------|
| **Agent** | An AI assistant using git-memory for persistent context | LLM, AI, model, bot |
| **Session** | One continuous conversation between a user and an agent | Chat, conversation, thread |

## Relationships

- A **Memory store** contains zero or more **Memories**
- A **Memory** has exactly one **Subject** and optionally one **Body**
- A **Memory** has zero or more **Tags**
- A **Forgotten** memory is still a **Memory** — just excluded from normal search
- An **Agent** reads from and writes to one **Memory store** per **Session**

## Example Dialogue

> **Dev:** "When an agent stores a memory, does it search for dupes first?"
>
> **Domain expert:** "Yes — `git-mem add` runs a **dedup** check against existing **subjects**. If word overlap exceeds the threshold, it warns. Use `--yes` to skip the prompt."
>
> **Dev:** "What if I accidentally stored something wrong? Can I delete it?"
>
> **Domain expert:** "No deletion — we **forget** it. The **memory** stays in history but is excluded from search. You can **resurface** it later if needed."
>
> **Dev:** "So git-memory is like a search index for my notes?"
>
> **Domain expert:** "No — it's a **decision cache**. A search index finds existing information. Git-memory stores your conclusions: what you learned, what you decided, what to avoid next time. The agent doesn't search the web or codebase — it recalls what you already figured out."
