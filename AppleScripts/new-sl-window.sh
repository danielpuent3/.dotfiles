#!/bin/bash

SESSION="SL"
WINDOW="DEPLOY"
TMUX_BIN="/opt/homebrew/bin/tmux"  # adjust if needed

# 1. Create session if it doesn't exist
if ! $TMUX_BIN has-session -t "$SESSION" 2>/dev/null; then
  $TMUX_BIN new-session -d -s "$SESSION" -n HOLD -c ~ "$SHELL"
fi

# 2. Create window if it doesn't exist
if ! $TMUX_BIN list-windows -t "$SESSION" | grep -q ": $WINDOW"; then
  $TMUX_BIN new-window -t "$SESSION" -n "$WINDOW" -c ~ "$SHELL"
fi

# 3. Select the window (safe even if already active)
$TMUX_BIN select-window -t "$SESSION:$WINDOW"

# 4. Attach to the session
exec $TMUX_BIN attach-session -t "$SESSION"