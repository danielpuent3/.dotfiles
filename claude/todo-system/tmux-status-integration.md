# tmux status integration

How the terminal knows what a session is working on, and how the wrong-branch
alarm works. Adapted from the source system's `statusline-integration.md`,
which used iTerm2-only OSC 1337 escape codes for the alarm — those do nothing
in Hyper and get eaten by tmux, so the alarm is a tmux `status-right` segment
here instead.

---

## 1. Showing the bound todo

`statusline-command.sh` gets `session_id` on stdin and resolves it to a slug:

```bash
slug=$("$HOME/.local/bin/todo-session" get --session-id "$session_id" 2>/dev/null)
[ -n "$slug" ] && printf '📝 %s' "$slug"
```

That's the whole feature. The status line never reads the conversation — the
binding file under `~/.ai/todos/.sessions/` is the entire channel between
"what I'm working on" and "what the terminal displays."

## 2. The wrong-branch alarm

Fires only when **all three** hold:

1. The session is bound to a todo
2. That todo lists branches for **the repo the pane's cwd is actually in**
3. The checked-out branch is not one of them

Condition 2 is what makes it usable on multi-repo items — standing in one repo
while the todo's only live branch is in another isn't a mistake, so it stays
quiet. It fails to silent, never to a false alarm: no todo, no branches,
detached HEAD, no git remote all produce nothing.

## 3. Mapping a tmux pane to a Claude session

The status line's stdout only reaches Claude Code's own renderer — it has no
way to write into the tmux status bar. So the alarm is a separate script,
invoked directly by tmux via `status-right`'s `#(...)` shell-command
expansion, not the statusline script.

The piece that makes this reliable: Claude Code's own session registry
(`~/.claude/sessions/<pid>.json`) already tags each session with the tmux
pane it's running in —

```json
{"sessionId": "...", "tmux": "session-name:window-id.pane-id", ...}
```

So `tmux-todo-status.sh` just greps the registry for the current pane's
target string instead of walking the pane's process tree looking for a
`claude` process:

```bash
matched_file="$(grep -lF "\"tmux\":\"$pane_target\"" "$CLAUDE_DIR"/sessions/*.json | head -1)"
```

Wired into `.tmux.conf` as:

```tmux
#(~/.dotfiles/claude/todo-system/bin/tmux-todo-status.sh '#{session_name}:#{window_id}.#{pane_id}' #{pane_current_path})
```

`#(...)` output is cached by tmux for the status-interval, so this runs on a
timer rather than a true redraw storm.

## Design note: the alarm is an alarm, not a display

The thing worth keeping even if the code changes: the status line is the
dashboard you read; the alarm is what you notice without reading anything.
It should be silent in the normal case and loud in the exceptional one — a
segment that's always showing something just becomes a second status line
you stop seeing within a day.
