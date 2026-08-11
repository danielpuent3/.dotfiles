#!/usr/bin/env bash
# macOS desktop notification for Claude Code Stop / Notification / StopFailure hooks.
# Reads the hook payload on stdin. Always exits 0 — a nonzero exit on Stop would
# block Claude from ending its turn.

set -uo pipefail

NOTIFIER=/opt/homebrew/bin/terminal-notifier
TMUX_BIN=/opt/homebrew/bin/tmux
JQ=/opt/homebrew/bin/jq

[[ -x "$NOTIFIER" && -x "$JQ" ]] || exit 0

input=$(cat)
[[ -n "$input" ]] || exit 0

event=$("$JQ" -r '.hook_event_name // "Stop"' <<<"$input" 2>/dev/null) || exit 0
session=$("$JQ" -r '.session_id // "unknown"' <<<"$input" 2>/dev/null)
cwd=$("$JQ" -r '.cwd // ""' <<<"$input" 2>/dev/null)

window=""
target=""
if [[ -n "${TMUX_PANE:-}" && -x "$TMUX_BIN" ]]; then
  fmt='#{session_attached}|#{window_active}|#S:#I|#W'
  if info=$("$TMUX_BIN" display-message -p -t "$TMUX_PANE" "$fmt" 2>/dev/null); then
    IFS='|' read -r attached active target window <<<"$info"
    # Watching this window right now means the terminal already told you.
    [[ "$attached" != "0" && "$active" == "1" ]] && exit 0
  fi
fi

# jq does the extraction, whitespace collapse, and truncation in one pass so the
# cut lands on a character boundary rather than mid-codepoint.
body=$("$JQ" -r --arg e "$event" '
  (if $e == "Stop" then (.last_assistant_message // "")
   elif $e == "Notification" then (.message // "Waiting on you")
   else ([.error_type, .message, .error, .reason] | map(select(. != null and . != "")) | join(": "))
   end)
  | gsub("\\s+"; " ")
  | sub("^ +"; "") | sub(" +$"; "")
  | if length > 180 then .[0:177] + "..." else . end
' <<<"$input" 2>/dev/null)

case "$event" in
  Stop)          verb="finished";  sound="Glass" ;;
  Notification)  verb="needs you"; sound="Ping" ;;
  StopFailure)   verb="failed";    sound="Basso" ;;
  *)             verb="$event";    sound="Glass" ;;
esac

[[ -n "$body" ]] || body="(no output)"

if [[ -n "$window" ]]; then
  title="Claude $verb · $window"
  subtitle="tmux $target${cwd:+ · ${cwd##*/}}"
else
  title="Claude $verb${cwd:+ · ${cwd##*/}}"
  subtitle="$cwd"
fi

click="/usr/bin/open -b co.zeit.hyper"
[[ -n "${TMUX_PANE:-}" && -x "$TMUX_BIN" ]] &&
  click="$TMUX_BIN switch-client -t $TMUX_PANE 2>/dev/null; $click"

"$NOTIFIER" \
  -title "$title" \
  -subtitle "$subtitle" \
  -message "$body" \
  -group "claude-$session" \
  -sound "$sound" \
  -execute "$click" >/dev/null 2>&1

exit 0
