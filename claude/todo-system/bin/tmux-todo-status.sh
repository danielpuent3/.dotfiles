#!/usr/bin/env bash
#
# tmux-todo-status.sh — wrong-branch alarm for tmux's status-right.
#
# Reimplements the todo system's wrong-branch check (see
# tmux-status-integration.md) as a tmux status segment: bound todo -> todo
# lists branches for *this* repo -> current branch isn't one of them. Silent
# unless all three hold.
#
# Claude Code's own session registry (~/.claude/sessions/<pid>.json) tags each
# session with the tmux pane it's running in, as
# "tmux":"<session_name>:<window_id>.<pane_id>" — so rather than walking the
# pane's process tree looking for a `claude` process, this matches directly on
# that field.
#
# Usage (in tmux status-right, via format expansion):
#   #(~/.dotfiles/claude/todo-system/bin/tmux-todo-status.sh '#{session_name}:#{window_id}.#{pane_id}' #{pane_current_path})
#
# Exits 0 always — a status-right command that errors blanks the whole bar.

set -uo pipefail

TODOS_DIR="${TODOS_DIR:-$HOME/.ai/todos}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TODO_SESSION="${TODO_SESSION_BIN:-$HOME/.local/bin/todo-session}"

pane_target="${1:-}"
pane_cwd="${2:-}"

theme="$(cat "$HOME/.dotfiles/.theme" 2>/dev/null || echo dark)"
if [ "$theme" = "light" ]; then
    C_RED='#BF616A'
    C_DIM='#4C566A'
else
    C_RED='#BF616A'
    C_DIM='#88C0D0'
fi

out() { printf '%s' "$1"; exit 0; }

[ -n "$pane_target" ] && [ -n "$pane_cwd" ] || out ""
[ -x "$TODO_SESSION" ] || out ""

# --- find the interactive claude session bound to this exact tmux pane ---
matched_file="$(grep -lF "\"tmux\":\"$pane_target\"" "$CLAUDE_DIR"/sessions/*.json 2>/dev/null | head -1)"
[ -n "$matched_file" ] || out ""

pid="$(basename "$matched_file" .json)"
kill -0 "$pid" 2>/dev/null || out ""   # registry entry outlived its process

session_id="$(sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' "$matched_file" | head -1)"
[ -n "$session_id" ] || out ""

slug="$("$TODO_SESSION" get --session-id "$session_id" 2>/dev/null)"
[ -n "$slug" ] || out ""

todo_file="$TODOS_DIR/$slug/TODO.md"
[ -f "$todo_file" ] || out ""

# frontmatter only, shared by the branch check and the model check below
frontmatter="$(awk '/^---$/{c++; next} c==1' "$todo_file")"

branch_alert=""
model_alert=""

# --- condition 2: does the todo list branches for the repo this pane is in? ---
check_branch() {
    local remote_url url url_parts n cur_nwo cur_branch
    local branches_line inner expected_branch matched_repo entries entry repo branch

    remote_url="$(git -C "$pane_cwd" remote get-url origin 2>/dev/null)"
    [ -n "$remote_url" ] || return
    url="${remote_url%.git}"
    url="${url//:/\/}"
    IFS='/' read -ra url_parts <<< "$url"
    n="${#url_parts[@]}"
    [ "$n" -ge 2 ] || return
    cur_nwo="${url_parts[$((n - 2))]}/${url_parts[$((n - 1))]}"

    cur_branch="$(git -C "$pane_cwd" symbolic-ref --short HEAD 2>/dev/null)"
    [ -n "$cur_branch" ] || return

    # only the flow-style `branches: ["a/b:c", ...]` form
    branches_line="$(printf '%s\n' "$frontmatter" | grep '^branches:' | head -1)"
    inner="$(printf '%s' "$branches_line" | sed -n 's/^branches: *\[\(.*\)\]/\1/p')"
    [ -n "$inner" ] || return

    expected_branch=""
    matched_repo=0
    IFS=',' read -ra entries <<< "$inner"
    for entry in "${entries[@]}"; do
        entry="$(printf '%s' "$entry" | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
        repo="${entry%%:*}"
        branch="${entry#*:}"
        [ "$repo" = "$cur_nwo" ] || continue
        matched_repo=1
        [ "$branch" = "$cur_branch" ] && return   # on an expected branch, all quiet
        expected_branch="$branch"
    done

    [ "$matched_repo" -eq 1 ] || return   # this repo isn't one the todo tracks

    branch_alert="#[fg=$C_RED,bold]⚠ WRONG BRANCH#[fg=$C_DIM,nobold] → ${expected_branch}#[default]"
}
check_branch

# --- condition 3: has the live session drifted off the todo's recommended model? ---
check_model() {
    local recommended running raw pane_id helper cmd_pid watchdog_pid

    recommended="$(printf '%s\n' "$frontmatter" | grep '^model:' | head -1 | sed -E 's/^model: *"?//; s/"?[[:space:]]*$//')"
    [ -n "$recommended" ] || recommended="opus"

    helper="${PANE_MODEL_BIN:-$HOME/.dotfiles/claude/todo-system/bin/pane-model.sh}"
    [ -x "$helper" ] || return
    pane_id="${pane_target##*.}"

    raw="$(set -m
        "$helper" "$pane_id" 2>/dev/null & cmd_pid=$!
        ( sleep 1; kill -TERM -- "-$cmd_pid" 2>/dev/null ) >/dev/null 2>&1 & watchdog_pid=$!
        wait "$cmd_pid" 2>/dev/null
        kill "$watchdog_pid" 2>/dev/null
        wait "$watchdog_pid" 2>/dev/null)"

    case "$raw" in
        opus|sonnet|haiku) running="$raw" ;;
        *) return ;;   # unknown isn't drift
    esac

    [ "$running" = "$recommended" ] && return

    model_alert="#[fg=$C_RED,bold]⚡${running}≠${recommended}#[default]"
}
check_model

segments=()
[ -n "$branch_alert" ] && segments+=("$branch_alert")
[ -n "$model_alert" ] && segments+=("$model_alert")
[ "${#segments[@]}" -gt 0 ] || out ""

out "${segments[*]}"
