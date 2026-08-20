#!/usr/bin/env bash
#
# pane-model.sh <pane_id> — print the running model for a tmux pane's Claude
# status line: opus, sonnet, haiku, or unknown. Always exits 0.
#
set -uo pipefail

TMUX_CMD="${TMUX_BIN:-}"
[ -n "$TMUX_CMD" ] || TMUX_CMD="$(command -v tmux 2>/dev/null)"
[ -n "$TMUX_CMD" ] || TMUX_CMD=/opt/homebrew/bin/tmux

pane="${1:-}"
[ -n "$pane" ] || { echo unknown; exit 0; }

tail="$("$TMUX_CMD" capture-pane -p -t "$pane" 2>/dev/null | tail -15)"
[ -n "$tail" ] || { echo unknown; exit 0; }

sline="$(grep -E '\[[█░]+\] *[0-9]+%' <<<"$tail" | tail -1)"
[ -n "$sline" ] || { echo unknown; exit 0; }

if grep -qi haiku <<<"$sline"; then echo haiku
elif grep -qi sonnet <<<"$sline"; then echo sonnet
elif grep -qi opus <<<"$sline"; then echo opus
else echo unknown
fi
exit 0
