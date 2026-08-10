# File-based todo system for Claude Code sessions

Adapted from a system a friend shared. One folder per work item, plain
markdown with YAML frontmatter, kept outside any conversation so it survives
past a session ending.

```
~/.ai/todos/
  INDEX.md                    <- the queue: everything active, one line each
  TEMPLATE.md
  bin/
    todo-session               <- binds a session to the item it's working on
    tmux-todo-status.sh         <- wrong-branch alarm for tmux's status-right
  some-work-item/
    TODO.md                    <- frontmatter + Task / Context / Plan / Notes
    screenshot.png              <- any supporting files live alongside
  archive/
    finished-item/
      TODO.md
```

`README.md`, `SPEC.md`, `TEMPLATE.md`, and `bin/` here are the source of
truth and travel with this dotfiles repo. `~/.ai/todos/` itself — the actual
queue and TODO items — is machine-local and untracked; it's real work state,
not config.

## What ties it together

- **A session knows what it's working on.** `todo-session set <slug>` binds
  the current Claude session to an item. `statusline-command.sh` reads it and
  shows it in the Claude Code status line.
- **tmux warns you on the wrong branch.** `tmux-todo-status.sh` reads the
  bound todo's `branches:` field and puts a `WRONG BRANCH` segment in the
  tmux status-right if the pane's current branch isn't one of them. Silent
  when everything's fine. See `tmux-status-integration.md`.

This machine's setup already wires both of those in via `setup.sh`/
`update.sh` — nothing further to install. See `SPEC.md` for the frontmatter
schema and day-to-day workflow.

## Starting a new item

```bash
mkdir ~/.ai/todos/my-item
cp ~/.ai/todos/TEMPLATE.md ~/.ai/todos/my-item/TODO.md
# fill in the frontmatter, then:
todo-session set my-item
```

Add a line for it under the right section of `~/.ai/todos/INDEX.md`.

## Honest caveats

- **It only works if it's maintained.** If sessions don't update it, it rots
  into a stale list you stop trusting.
- **It's more ceremony than most work needs.** For a one-off fix, just do the
  fix. This earns its keep on multi-day, multi-repo work.
