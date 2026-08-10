# Spec

Reference for the frontmatter schema, body structure, and workflow. Read
`README.md` first — this is the lookup doc, not the intro.

---

## File layout

Each item lives in its own folder named after its slug. The folder holds `TODO.md`
plus any supporting files — specs, screenshots, logs, exports.

```
~/.ai/todos/
  README.md
  INDEX.md
  TEMPLATE.md
  bin/
    todo-session
    tmux-todo-status.sh
  .sessions/              <- session-id -> slug bindings, managed by todo-session
    <session-id>
  slug-of-work-item/
    TODO.md
    context-file.png
  archive/
    finished-slug/
      TODO.md
```

Slugs are lowercase and hyphen-separated.

---

## Frontmatter

```yaml
---
id: stable-id-or-date-slug
title: "Human title"
type: task              # task | project | support-ticket
group: []               # ad-hoc grouping slugs, e.g. ["q3-billing-cleanup"]
status: next            # now | next | doing | waiting | blocked | done | cancelled
priority: normal        # low | normal | high | urgent
owner: Your Name
requester: null
project_directory: /absolute/path/to/repo
slack_urls: []
source_urls: []
projects: []
support_tickets: []
pr_urls: []
branches: []            # repo-qualified: ["owner/repo:branch-name"]
affected_user_ids: []
created: YYYY-MM-DD
due: null
completed: null
archived_reason: null
---
```

### `project_directory`

Absolute path to the repo this item's work primarily happens in. Required — the
system isn't scoped to one checkout, so an agent needs to know where to run tests,
`git`, or build commands before it runs them.

### `branches`

**Repo-qualified**, as `owner/repo:branch-name`. The prefix is required because one
item can span several repos and consumers need to know which branch belongs to
which checkout — `project_directory` names only the primary one.

Lifecycle:

- A branch belongs here while it's **live work** — an open PR's head branch, or a
  local branch not yet PR'd.
- **Remove it once the PR merges.** A merged branch is history; it goes in `Notes`.
- Abandoned branches come out too, with the abandonment recorded in `Notes`.
- `branches: []` is the normal resting state, not an omission.

⚠️ Keep this current. The tmux wrong-branch alarm reads it — a stale entry
produces a false alarm, and a missing one silently disables the check.

### `group`

Lowercase hyphenated slugs for ad-hoc groupings that cut across `type`. An item can
be in several. Groups are informal — there's no registry; a group exists because at
least one item names it.

```bash
grep -l 'group:.*"the-slug"' ~/.ai/todos/*/TODO.md
```

### Type values

| Value | Meaning |
|---|---|
| `task` | small standalone follow-up, chore, reminder, or investigation |
| `project` | durable multi-step initiative or context area |
| `support-ticket` | user-reported issue needing triage, investigation, or fix |

### Status values

| Value | Meaning |
|---|---|
| `now` | highest-priority item, pick this up first |
| `next` | active queue item, not yet started |
| `doing` | actively being worked |
| `waiting` | waiting on review, deploy, confirmation, or another person |
| `blocked` | cannot move without an external dependency |
| `done` | completed — archive immediately |
| `cancelled` | intentionally dropped — archive immediately |

### Priority values

`low` · `normal` · `high` · `urgent`

---

## Body structure

Four sections, in this order:

```markdown
## Task
Plain description of what needs to happen.

## Context
Slack summary, source links, code pointers, constraints, related files.

## Plan
Next steps, subtask checklist, or implementation direction.

## Notes

### YYYY-MM-DD
- Append-only dated notes for meaningful actions and discoveries.
```

**`Task`, `Context`, and `Plan` are edited in place** as understanding improves.
**`Notes` is append-only** — it's the record of what actually happened, including
the wrong turns. Don't rewrite history there; the wrong turns are often the most
useful part when you come back in three weeks.

---

## The queue — `INDEX.md`

Active items only, grouped by status:

```markdown
## Now
## Next
## Doing
## Waiting
## Blocked
```

One line per item:

```markdown
- `slug-of-work-item` - [priority][type] one-line summary -> PR #123
```

Work `Now` → `Doing` → `Next`. Within a section, prefer urgent/high, then older
`created` dates. Explicit direction from a human always overrides the queue.

---

## Workflow

**Creating:**

1. `mkdir ~/.ai/todos/slug-of-work-item/`
2. Copy `TEMPLATE.md` to `TODO.md`, fill in frontmatter including `project_directory`
3. Drop any context files in the same folder
4. Add a line to `INDEX.md` under the right section

**Updating:**

- Keep status, priority, PR URLs, and branches current
- When a PR merges or is abandoned, drop its branch from `branches` in the same pass
- Append dated notes for meaningful actions
- Keep `INDEX.md` synchronized

**Archiving:**

1. Set `status` to `done` or `cancelled`
2. Fill in `completed` and `archived_reason`
3. Move the whole folder to `~/.ai/todos/archive/`
4. Remove its line from `INDEX.md`
5. `todo-session clear` if the current session was bound to it

---

## Session binding

Binds a Claude session to the one item it's working on, so tooling can answer
"what is this session working on?" without reading the conversation.

```
todo-session set <slug>                 bind this session
todo-session get [--session-id <id>]    print the bound slug (exit 1 if none)
todo-session clear                      unbind
todo-session list                       every live binding, with cwd and age
todo-session prune [--dry-run]          remove dead bindings
```

**Bind when** you pick an item up, when work shifts to a different item mid-session,
or when you create one and start immediately. It's idempotent — last write wins.

**Don't bind** when you're only reading the queue. Otherwise the status line thrashes
on every "what's pending?".

### Storage

One file per session under `.sessions/` — filename is the session id, contents are
the slug, mtime is when it was last touched. Separate files rather than one JSON map
because sessions run concurrently: this keeps writes atomic and lock-free, and the
read path a bare `cat`.

Session id resolves automatically from `~/.claude/sessions/<pid>.json`, falling back
to `$CLAUDE_CODE_SESSION_ID`. `--session-id` overrides both — that's how the status
line and tmux script look up the id.

`set` validates the slug against a real folder and refuses one that doesn't resolve,
so a typo never reaches the status line.

### Cleanup

Not a separate chore — every mutating command prunes dead bindings as a side effect,
so `.sessions/` can't grow without bound.

A binding is dead when its slug no longer resolves, its session is gone (no live
process and no transcript), or it's older than 30 days
(`TODO_SESSION_MAX_AGE_DAYS` to override).

One subtlety: the session doing the pruning is never reaped, even if it hasn't
landed in the process registry yet. Without that exemption, `set` could reap the
binding it just wrote.
