#!/usr/bin/env bash
#
# todo-orchestrator helper.
#
# Emits compact, line-oriented digests so an orchestrating Claude session can
# run the queue without ever loading a TODO body into its context.
#
#   orch.sh standup [--since YYYY-MM-DD]   full morning digest
#   orch.sh quote                          one inspiration quote
#   orch.sh board                          queue + window state only
#   orch.sh windows                        tmux windows and their bound todos
#   orch.sh open <slug> [opts]             open a tmux window working that todo
#   orch.sh send <slug> <text>             type text into that todo's window
#   orch.sh close <slug>                   kill that todo's window
#   orch.sh show <slug>                    frontmatter + section line offsets
#   orch.sh list                           every slug, one per line
#
set -uo pipefail

TODOS="${TODO_HOME:-$HOME/.ai/todos}"
SESSIONS="$TODOS/.sessions"
PULSE_LOG="$TODOS/.pulse"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_CMD="${TMUX_BIN:-}"
[ -n "$TMUX_CMD" ] || TMUX_CMD="$(command -v tmux 2>/dev/null)"
[ -n "$TMUX_CMD" ] || TMUX_CMD=/opt/homebrew/bin/tmux
CLAUDE_BIN="${ORCH_CLAUDE_BIN:-claude}"
FZF_CMD="${FZF_BIN:-}"
[ -n "$FZF_CMD" ] || FZF_CMD="$(command -v fzf 2>/dev/null)"
[ -n "$FZF_CMD" ] || FZF_CMD=/opt/homebrew/bin/fzf
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

die() { echo "ERROR|$*" >&2; exit 1; }

todo_dirs() {
  find "$TODOS" -mindepth 2 -maxdepth 2 -name TODO.md -not -path "*/archive/*" 2>/dev/null | sort
}

slug_dir() {
  local d="$TODOS/$1"
  [ -f "$d/TODO.md" ] || die "no such todo: $1"
  printf '%s' "$d"
}

# scalar frontmatter value
fm() {
  awk -v k="$2" '
    NR==1 && $0=="---" { inf=1; next }
    inf && $0=="---"   { exit }
    inf {
      p = k ": "
      if (substr($0, 1, length(p)) == p) {
        v = substr($0, length(p)+1)
        gsub(/^"|"$/, "", v)
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        print v; exit
      }
    }' "$1"
}

# list frontmatter value, inline [] or block "  - " form, joined with ";"
fmlist() {
  awk -v k="$2" '
    NR==1 && $0=="---" { inf=1; next }
    inf && $0=="---"   { exit }
    inf {
      if (collect) {
        if (substr($0,1,4) == "  - ") { v=substr($0,5); out = out (out?";":"") v; next }
        collect = 0
      }
      p = k ":"
      if (substr($0, 1, length(p)) == p) {
        rest = substr($0, length(p)+1)
        gsub(/^[ \t]+|[ \t]+$/, "", rest)
        if (rest == "")   { collect = 1; next }
        if (rest == "[]") { next }
        gsub(/^\[|\]$/, "", rest)
        out = rest
      }
    }
    END { print out }' "$1"
}

trunc() { awk -v n="$2" '{ print (length($0) > n ? substr($0,1,n) "..." : $0) }' <<<"$1"; }

default_since() {
  local dow back
  dow="$(date +%u)"
  back=1
  [ "$dow" = 1 ] && back=3   # Monday reaches back to Friday
  [ "$dow" = 7 ] && back=2
  date -v-"${back}"d +%F
}

cmd_quote() {
  local f="$SKILL_DIR/quotes.txt" n i
  n="$(grep -c . "$f")"
  i=$(( (RANDOM % n) + 1 ))
  echo "QUOTE|$(sed -n "${i}p" "$f")"
}

cmd_windows() {
  "$TMUX_CMD" list-windows -a -F 'WINDOW|#{window_id}|#{window_index}|#{window_name}|#{@todo}|#{pane_current_path}|#{window_panes}|#{?window_active,active,}' 2>/dev/null
  if [ -x "$TODOS/bin/todo-session" ]; then
    "$TODOS/bin/todo-session" list 2>/dev/null | awk 'NR>1 && NF { id=$1; slug=$2; age=$3; cwd=""; for(i=4;i<=NF;i++) cwd=cwd (cwd?" ":"") $i; print "BOUND|" slug "|" age "|" cwd }'
  fi
}

cmd_board() {
  awk '
    /^## / { sec = substr($0, 4); next }
    /^- `/ {
      line = $0
      sub(/^- /, "", line)
      if (length(line) > 240) line = substr(line, 1, 240) "..."
      print "INDEX|" sec "|" line
    }' "$TODOS/INDEX.md"

  local f slug
  while read -r f; do
    slug="$(basename "$(dirname "$f")")"
    printf 'TODO|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$slug" \
      "$(fm "$f" status)" \
      "$(fm "$f" priority)" \
      "$(fm "$f" type)" \
      "$(fm "$f" created)" \
      "$(date -r "$f" +%F)" \
      "$(fmlist "$f" branches)" \
      "$(fmlist "$f" pr_urls)" \
      "$(fm "$f" model)"
  done < <(todo_dirs)

  # queue / filesystem drift
  local indexed
  indexed="$(grep -o '^- `[^`]*`' "$TODOS/INDEX.md" | tr -d '`' | sed 's/^- //' | sort)"
  while read -r f; do
    slug="$(basename "$(dirname "$f")")"
    grep -qx "$slug" <<<"$indexed" || echo "ORPHAN|$slug|folder exists, no INDEX line"
  done < <(todo_dirs)
  while read -r slug; do
    [ -n "$slug" ] || continue
    [ -f "$TODOS/$slug/TODO.md" ] || echo "GHOST|$slug|INDEX line, no folder"
  done <<<"$indexed"
}

cmd_notes() {
  local since="$1" f slug
  while read -r f; do
    slug="$(basename "$(dirname "$f")")"
    awk -v since="$since" -v slug="$slug" '
      /^### 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ { d = substr($2,1,10); active = (d >= since); n = 0; next }
      /^## / { active = 0 }
      active && NF {
        if (n++ >= 8) next
        line = $0
        gsub(/^[ \t]*[-*][ \t]*/, "", line)
        if (length(line) > 200) line = substr(line, 1, 200) "..."
        print "NOTE|" slug "|" d "|" line
      }' "$f"
  done < <(todo_dirs)
}

cmd_git() {
  local since="$1" dirs d email
  dirs="$(while read -r f; do fm "$f" project_directory; done < <(todo_dirs) | sort -u)"
  while read -r d; do
    [ -n "$d" ] && [ -d "$d/.git" ] || continue
    email="$(git -C "$d" config user.email 2>/dev/null)"
    [ -n "$email" ] || continue
    git -C "$d" log --all --no-merges --since="$since 00:00" --author="$email" \
      --pretty=format:"GIT|$(basename "$d")|%ad|%h|%s" --date=short -n 12 2>/dev/null
    echo
  done <<<"$dirs" | grep '^GIT|' | sort -u
}

cmd_standup() {
  local since="${1:-$(default_since)}"
  echo "TODAY|$(date +%F)|$(date +%A)"
  echo "SINCE|$since"
  cmd_quote
  cmd_notes "$since"
  cmd_git "$since"
  cmd_board
  cmd_windows
  cmd_pulse "${since}T00:00:00"
}

cmd_show() {
  local d f
  d="$(slug_dir "$1")" || exit 1
  f="$d/TODO.md"
  sed -n '/^---$/,/^---$/p' "$f"
  echo "---"
  grep -n '^## \|^### ' "$f" | sed 's/^/OUTLINE|/'
  echo "FILE|$f"
  echo "LINES|$(wc -l < "$f" | tr -d ' ')"
  ls -1 "$d" | grep -v '^TODO.md$' | sed 's/^/ATTACHMENT|/'
}

cmd_list() {
  local f
  while read -r f; do basename "$(dirname "$f")"; done < <(todo_dirs)
}

# Window naming: <repo-alias>/<hint>, so the repo is always the first thing you
# read in the status bar and two todos in the same repo never collide.
repo_alias() {
  local b; b="$(basename "${1:-}")"
  case "$b" in
    streamlabs-identity-api)       echo slid-api ;;
    streamlabs-identity-web)       echo slid-web ;;
    streamlabs-identity-laravel)   echo slid-php ;;
    streamlabs.com)                echo core ;;
    charity-laravel)               echo charity ;;
    charity-homestead)             echo charity-hs ;;
    oracle-invoice-job)            echo oracle ;;
    oracle-billing)                echo oracle-bl ;;
    stripe-incident-*)             echo stripe ;;
    streamlabs-docker-environment) echo env ;;
    .dotfiles)                     echo dotfiles ;;
    streamlabs-ledger)             echo ledger ;;
    streamlabs-r2d2)               echo r2d2 ;;
    logi-billing-php)              echo logi-bill ;;
    treasury-paypal)               echo treasury ;;
    crossclip-api)                 echo crossclip ;;
    ultra-web)                     echo ultra ;;
    sl-one-fe-sdk)                 echo sl-one-sdk ;;
    "")                            echo todo ;;
    *) printf '%s' "$b" | sed -e 's/^streamlabs-//' -e 's/-laravel$//' -e 's/\.com$//' | cut -c1-10 ;;
  esac
}

# First slug token that is not already carried by the alias.
win_hint() {
  local slug="$1" alias="$2" tok
  for tok in ${slug//-/ }; do
    case "/$alias/" in *"/$tok/"*) continue ;; esac
    case "$alias" in *"$tok"*) continue ;; esac
    printf '%s' "$tok" | cut -c1-10
    return 0
  done
  printf '%s' "${slug%%-*}" | cut -c1-10
}

# Explicit `window:` frontmatter wins; otherwise alias/hint, +N if tmux already
# has that name on a window bound to a different todo.
win_name_for() {
  local slug="$1" dir="$2" f="$3" name alias taken n=2
  name="$(fm "$f" window)"
  if [ -z "$name" ]; then
    alias="$(repo_alias "$dir")"
    name="$alias/$(win_hint "$slug" "$alias")"
  fi
  taken="$("$TMUX_CMD" list-windows -a -F '#{window_name}|#{@todo}' 2>/dev/null | awk -F'|' -v s="$slug" '$2!=s {print $1}')"
  local base="$name"
  while printf '%s\n' "$taken" | grep -qxF "$name"; do
    name="$base$n"; n=$((n+1))
    [ "$n" -gt 9 ] && break
  done
  printf '%s' "$name"
}

cmd_open() {
  local slug="" name="" prompt="" switch=0 force=0 dir="" model=""
  slug="${1:-}"; shift || true
  [ -n "$slug" ] || die "usage: orch.sh open <slug> [--name X] [--prompt X] [--switch] [--force] [--dir X] [--model opus|sonnet|haiku]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --name)   name="$2"; shift 2 ;;
      --prompt) prompt="$2"; shift 2 ;;
      --dir)    dir="$2"; shift 2 ;;
      --model)  model="$2"; shift 2 ;;
      --switch) switch=1; shift ;;
      --force)  force=1; shift ;;
      *) die "unknown option: $1" ;;
    esac
  done

  local d; d="$(slug_dir "$slug")" || exit 1
  [ -n "$dir" ] || dir="$(fm "$d/TODO.md" project_directory)"
  [ -n "$model" ] || model="$(fm "$d/TODO.md" model)"
  [ -n "$model" ] || model=opus
  case "$model" in
    opus|sonnet|haiku) ;;
    *) die "invalid model: $model (must be opus, sonnet, or haiku)" ;;
  esac
  [ -d "$dir" ] || die "project_directory does not exist: $dir"
  "$TMUX_CMD" has-session -t 0 2>/dev/null || "$TMUX_CMD" list-sessions >/dev/null 2>&1 || die "no tmux server running"

  local existing
  existing="$("$TMUX_CMD" list-windows -a -F '#{window_id}|#{@todo}|#{window_index}|#{window_name}' 2>/dev/null \
    | awk -F'|' -v s="$slug" '$2==s { print $1 "|" $3 "|" $4; exit }')"
  if [ -n "$existing" ] && [ "$force" -eq 0 ]; then
    [ "$switch" -eq 1 ] && "$TMUX_CMD" select-window -t "${existing%%|*}"
    echo "EXISTS|$existing|$slug|$model"
    return 0
  fi

  [ -n "$name" ] || name="$(win_name_for "$slug" "$dir" "$d/TODO.md")"

  local uuid
  uuid="$(uuidgen | tr 'A-Z' 'a-z')"
  mkdir -p "$SESSIONS"
  printf '%s' "$slug" > "$SESSIONS/$uuid"

  [ -n "$prompt" ] || prompt="You are picking up todo \`$slug\`. Run: todo-session set $slug. Then read $d/TODO.md, starting with the \`## Handoff\` section at the end if one exists, since that is where the previous session left off. Check git branch and status in $dir against its branches field, and give me a five-line status plus the single next action. Do not change anything until I confirm."

  local winid
  winid="$("$TMUX_CMD" new-window -d -P -F '#{window_id}' -n "$name" -c "$dir")" || die "tmux new-window failed"
  "$TMUX_CMD" set-option -w -t "$winid" @todo "$slug"
  "$TMUX_CMD" send-keys -t "$winid" "$CLAUDE_BIN --session-id $uuid --model $model $(printf '%q' "$prompt")" Enter
  [ "$switch" -eq 1 ] && "$TMUX_CMD" select-window -t "$winid"

  local idx
  idx="$("$TMUX_CMD" display-message -p -t "$winid" '#{window_index}')"
  echo "OPENED|$winid|$idx|$name|$slug|$dir|$uuid|$model"
}

WINDDOWN_STATE="$TODOS/.winddown"

winddown_prompt() {
  cat <<TXT
End of day wind-down for \`$1\`. This window is about to be closed, so bring $TODOS/$1/TODO.md fully up to date first — tomorrow starts from the file, not from your context. Append a dated note covering what you did today and anything you worked out that is not obvious from the diff; correct the status, branches and prs frontmatter; edit Task/Context/Plan in place if they moved; and end with a ## Handoff section giving the exact next action. Call out anything uncommitted, unpushed, or sitting in a worktree, stash or scratch file, with its path. Notes are append-only per SPEC. Reply DONE when the file is written.
TXT
}

# Ask every live bound window to write itself up. Unbound and stale windows are
# reported, not touched — deciding what they were is the orchestrator's job.
winddown_ask() {
  local selfwin="" pane win slug rest path mt asked=0
  selfwin="$("$TMUX_CMD" display -p -t "${TMUX_PANE:-}" '#{window_id}' 2>/dev/null)"
  : > "$WINDDOWN_STATE"

  local live=" "
  while IFS='|' read -r pane win slug branch state ctx cost path rest; do
    [ -n "$pane" ] || continue
    local winid; winid="$("$TMUX_CMD" display -p -t "$pane" '#{window_id}' 2>/dev/null)"
    [ "$winid" = "$selfwin" ] && continue
    if [ -z "$slug" ]; then
      echo "WINDDOWN|unbound|$winid|$win|$path|$state"
      continue
    fi
    live="$live$slug "
    mt="$(stat -f %m "$TODOS/$slug/TODO.md" 2>/dev/null || echo 0)"
    printf '%s\t%s\t%s\n' "$slug" "$mt" "$win" >> "$WINDDOWN_STATE"
    "$TMUX_CMD" send-keys -t "$winid" -l "$(winddown_prompt "$slug")"
    "$TMUX_CMD" send-keys -t "$winid" Enter
    plog "$slug" winddown-asked "$win"
    echo "WINDDOWN|asked|$slug|$win|$state"
    asked=$((asked+1))
  done < <(pulse_scan)

  # bound windows with no claude running: nothing to ask, safe to close
  "$TMUX_CMD" list-windows -a -F '#{window_id}|#{window_index}|#{window_name}|#{@todo}' 2>/dev/null \
    | while IFS='|' read -r winid idx win slug; do
        [ -n "$slug" ] || continue
        [ "$winid" = "$selfwin" ] && continue
        case "$live" in *" $slug "*) continue ;; esac
        echo "WINDDOWN|stale|$winid|$idx|$win|$slug"
      done

  echo "WINDDOWN|summary|asked=$asked"
}

winddown_status() {
  [ -s "$WINDDOWN_STATE" ] || { echo "WINDDOWN|none"; return 0; }
  local slug mt win now pending=0 upd=0
  while IFS=$'\t' read -r slug mt win; do
    [ -n "$slug" ] || continue
    now="$(stat -f %m "$TODOS/$slug/TODO.md" 2>/dev/null || echo 0)"
    if [ "$now" != "$mt" ]; then
      echo "WINDDOWN|updated|$slug|$win"; upd=$((upd+1))
    else
      echo "WINDDOWN|pending|$slug|$win"; pending=$((pending+1))
    fi
  done < "$WINDDOWN_STATE"
  echo "WINDDOWN|summary|updated=$upd|pending=$pending"
}

# Close only what wrote itself up, unless --all is passed.
winddown_close() {
  local all=0; [ "${1:-}" = "--all" ] && all=1
  [ -s "$WINDDOWN_STATE" ] || { echo "WINDDOWN|none"; return 0; }
  local slug mt win now n=0
  while IFS=$'\t' read -r slug mt win; do
    [ -n "$slug" ] || continue
    now="$(stat -f %m "$TODOS/$slug/TODO.md" 2>/dev/null || echo 0)"
    if [ "$now" = "$mt" ] && [ "$all" -eq 0 ]; then
      echo "WINDDOWN|kept|$slug|$win|never updated"
      continue
    fi
    cmd_close "$slug" >/dev/null 2>&1 && { echo "WINDDOWN|closed|$slug|$win"; n=$((n+1)); }
  done < "$WINDDOWN_STATE"
  : > "$WINDDOWN_STATE"
  echo "WINDDOWN|summary|closed=$n"
}

cmd_winddown() {
  case "${1:-ask}" in
    ask)    shift || true; winddown_ask "$@" ;;
    status) shift || true; winddown_status "$@" ;;
    close)  shift || true; winddown_close "$@" ;;
    *) die "usage: orch.sh winddown [ask|status|close [--all]]" ;;
  esac
}

cmd_send() {
  local slug="${1:-}"; shift || true
  local text="$*"
  [ -n "$slug" ] && [ -n "$text" ] || die "usage: orch.sh send <slug> <text>"
  local winid
  winid="$("$TMUX_CMD" list-windows -a -F '#{window_id}|#{@todo}' | awk -F'|' -v s="$slug" '$2==s { print $1; exit }')"
  [ -n "$winid" ] || die "no open window for $slug"
  "$TMUX_CMD" send-keys -t "$winid" -l "$text"
  "$TMUX_CMD" send-keys -t "$winid" Enter
  echo "SENT|$winid|$slug"
}

cmd_close() {
  local slug="${1:-}"
  [ -n "$slug" ] || die "usage: orch.sh close <slug>"
  local winid
  winid="$("$TMUX_CMD" list-windows -a -F '#{window_id}|#{@todo}' | awk -F'|' -v s="$slug" '$2==s { print $1; exit }')"
  [ -n "$winid" ] || die "no open window for $slug"
  "$TMUX_CMD" kill-window -t "$winid"
  echo "CLOSED|$winid|$slug"
}


# ── interactive picker ────────────────────────────────────────────────────────

C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
C_BLU=$'\033[34m'; C_MAG=$'\033[35m'; C_CYN=$'\033[36m'

status_face() {   # status -> "order glyph colour"
  case "$1" in
    now)     echo "0 ● $C_RED" ;;
    doing)   echo "1 ◉ $C_GRN" ;;
    waiting) echo "2 ◔ $C_YEL" ;;
    blocked) echo "3 ▲ $C_MAG" ;;
    next)    echo "4 ○ $C_CYN" ;;
    *)       echo "5 · $C_DIM" ;;
  esac
}

index_line() {    # one-line summary for a slug, stripped of slug and tags
  awk -v s="$1" '
    index($0, "`" s "`") { 
      line = $0
      sub(/^- `[^`]*` - /, "", line)
      sub(/^\[[a-z]+\]\[[a-z-]+\] /, "", line)
      print line; exit
    }' "$TODOS/INDEX.md"
}

window_for() {
  "$TMUX_CMD" list-windows -a -F '#{@todo}|#{window_name}|#{window_index}' 2>/dev/null \
    | awk -F'|' -v s="$1" '$1==s { print $2 " (" $3 ")"; exit }'
}

pick_list() {
  local f slug st pr face order glyph colour sum win row
  while read -r f; do
    slug="$(basename "$(dirname "$f")")"
    st="$(fm "$f" status)"; pr="$(fm "$f" priority)"
    face="$(status_face "$st")"
    order="${face%% *}"; glyph="$(cut -d' ' -f2 <<<"$face")"; colour="${face##* }"
    sum="$(index_line "$slug")"
    [ ${#sum} -gt 44 ] && sum="${sum:0:41}..."
    win="$(window_for "$slug")"
    row="$(printf '%s%s %-7s%s %-33s %s%-44s%s' \
      "$colour" "$glyph" "$st" "$C_RESET" "$slug" "$C_DIM" "$sum" "$C_RESET")"
    [ "$pr" = high ] || [ "$pr" = urgent ] && row="$row ${C_YEL}[$pr]${C_RESET}"
    [ -n "$win" ] && row="$row ${C_BLU}⧉ $win${C_RESET}"
    printf '%s\t%s\t%s\n' "$order" "$slug" "$row"
  done < <(todo_dirs) | sort -k1,1 -t$'\t' | cut -f2,3
}

cmd_preview() {
  local slug="${1:-}" d f
  [ -n "$slug" ] || return 0
  d="$TODOS/$slug"; f="$d/TODO.md"
  [ -f "$f" ] || { echo "no such todo"; return 0; }

  local st pr ty dir br prs win mo
  st="$(fm "$f" status)"; pr="$(fm "$f" priority)"; ty="$(fm "$f" type)"
  dir="$(fm "$f" project_directory)"
  br="$(fmlist "$f" branches)"; prs="$(fmlist "$f" pr_urls)"
  win="$(window_for "$slug")"
  mo="$(fm "$f" model)"

  printf '%s%s%s\n' "$C_BOLD" "$(fm "$f" title)" "$C_RESET"
  printf '%s%s · %s · %s%s\n\n' "$C_DIM" "$st" "$pr" "$ty" "$C_RESET"
  printf '%smodel%s   %s\n' "$C_CYN" "$C_RESET" "${mo:-opus}"
  printf '%srepo%s    %s\n' "$C_CYN" "$C_RESET" "$(basename "$dir")"
  printf '%sbranch%s  %s\n' "$C_CYN" "$C_RESET" "${br:-none}"
  printf '%spr%s      %s\n' "$C_CYN" "$C_RESET" "$(sed 's|https://github.com/[^/]*/[^/]*/pull/|#|g; s/;/ /g; s/"//g' <<<"${prs:-none}")"
  printf '%swindow%s  %s\n' "$C_CYN" "$C_RESET" "${win:-none open}"
  printf '%stouched%s %s\n' "$C_CYN" "$C_RESET" "$(date -r "$f" +%F)"

  printf '\n%s── plan ─────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"
  awk '/^## Plan/{p=1;next} /^## /{p=0} p && NF' "$f" | head -14

  printf '\n%s── latest note ──────────────────────────────%s\n' "$C_DIM" "$C_RESET"
  awk '/^### 20[0-9][0-9]-/{ if (seen) exit; seen=1; print "'"$C_BOLD"'" $0 "'"$C_RESET"'"; next } seen' "$f" | head -20
}

cmd_pick() {
  [ -x "$FZF_CMD" ] || die "fzf not found"
  local list sel slug key
  while :; do
    list="$(pick_list)"
    [ -n "$list" ] || die "no todos"

    sel="$(printf '%s\n' "$list" | "$FZF_CMD" \
      --ansi --delimiter='\t' --with-nth=2 --no-sort \
      --height=100% --layout=reverse --border=rounded \
      --border-label=' todo queue ' --border-label-pos=3 \
      --prompt='  open > ' --pointer='▸' --marker='✓' \
      --info=inline-right \
      --preview="$SELF preview {1}" \
      --preview-window='right,52%,border-left,wrap' \
      --bind="ctrl-r:reload($SELF _picklist)" \
      --bind='ctrl-/:toggle-preview' \
      --header=$'enter/ctrl-o open+switch · ctrl-t open in background · ctrl-x close window · ctrl-r reload\n' \
      --expect=ctrl-o,ctrl-t,ctrl-x)" || return 0

    key="$(head -1 <<<"$sel")"
    slug="$(sed -n '2p' <<<"$sel" | cut -f1)"
    [ -n "$slug" ] || return 0

    case "$key" in
      ctrl-x) cmd_close "$slug"; continue ;;
      ctrl-t) cmd_open "$slug" ;;
      *)      cmd_open "$slug" --switch ;;
    esac
    return 0
  done
}

cmd_popup() {
  local w="${1:-92%}" h="${2:-86%}"
  "$TMUX_CMD" display-popup -E -w "$w" -h "$h" \
    -T ' todo orchestrator ' \
    "if $SELF pick; then :; else printf '\\n  press any key '; read -rsn1; fi" >/dev/null 2>&1 &
  disown 2>/dev/null
  echo "POPUP|opened"
}


# ── pulse: live view of every claude window bound to a todo ───────────────────
#
# Reads state straight off each pane's Claude Code status line, which already
# carries the bound todo, branch, cost and context use. Transitions are appended
# to $PULSE_LOG so the orchestrator can read the day back without watching it.

plog() { printf '%s|%s|%s|%s\n' "$(date +%FT%T)" "$1" "$2" "${3:-}" >> "$PULSE_LOG"; }

pulse_scan() {   # pane|window|slug|branch|state|ctx|cost|path|hash|curmodel|recmodel|age|cold
  local p tail stail sline slug branch cost ctx state win curmodel recmodel age cold
  for p in $("$TMUX_CMD" list-panes -a -F '#{pane_id}' 2>/dev/null); do
    tail="$("$TMUX_CMD" capture-pane -p -t "$p" 2>/dev/null | tail -25)"
    # the live status line sits near the bottom, but trailing hint/agent lines can
    # follow it — search a short window, not the whole scrollback tail used for state
    stail="$(tail -8 <<<"$tail")"
    sline="$(grep -E '\[[█░]+\] *[0-9]+%' <<<"$stail" | tail -1)"
    [ -n "$sline" ] || continue
    if grep -qF '📝 ' <<<"$sline"; then
      slug="$(sed -n 's/.*📝 \([^ ][^ ]*\).*/\1/p' <<<"$sline")"
      branch="$(sed 's/.*📝 [^ ][^ ]*  *//; s/  .*//; s/ *[✓✗↑↓*].*//' <<<"$sline")"
    else
      slug=""
      branch="$(sed 's/^ *//; s/  .*//; s/ *[✓✗↑↓*].*//' <<<"$sline")"
    fi
    cost="$(grep -o '\$[0-9][0-9.,]*' <<<"$sline" | head -1)"
    ctx="$(grep -o '[0-9][0-9]*%' <<<"$sline" | tail -1)"
    if grep -q 'esc to interrupt' <<<"$tail"; then state=working
    elif grep -qE 'Do you want|Would you like|Proceed\?|\(y/n\)|^ *❯ *[0-9]\.|^ *[0-9]\. Yes|Press enter to' <<<"$tail"; then state=input
    else state=idle; fi
    win="$("$TMUX_CMD" display -p -t "$p" '#{window_name}' 2>/dev/null)"
    if grep -qi haiku <<<"$sline"; then curmodel=haiku
    elif grep -qi sonnet <<<"$sline"; then curmodel=sonnet
    elif grep -qi opus <<<"$sline"; then curmodel=opus
    else curmodel=unknown; fi
    if [ -n "$slug" ]; then
      recmodel="$(fm "$TODOS/$slug/TODO.md" model)"
      [ -n "$recmodel" ] || recmodel=opus
    else
      recmodel=""
    fi
    # session age and cold-cache resume cost come straight off the status line,
    # so pulse and the status line can never disagree.
    age="$(sed -n 's/.*⏱ \([0-9hm][0-9hm]*\).*/\1/p' <<<"$sline")"
    cold="$(sed -n 's/.*❄ [0-9hm][0-9hm]* ~\(\$[0-9.][0-9.]*\).*/\1/p' <<<"$sline")"
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$p" "$win" "$slug" "$branch" "$state" "${ctx:-–}" "${cost:-–}" \
      "$("$TMUX_CMD" display -p -t "$p" '#{pane_current_path}' 2>/dev/null)" \
      "$(cksum <<<"$tail" | cut -d' ' -f1)" "$curmodel" "$recmodel" "${age:-–}" "${cold:-}"
  done
}

ago() {   # seconds -> compact age
  local s=$1
  if   [ "$s" -lt 60 ]    ; then echo "${s}s"
  elif [ "$s" -lt 3600 ]  ; then echo "$((s/60))m"
  elif [ "$s" -lt 86400 ] ; then echo "$((s/3600))h"
  else echo "$((s/86400))d"; fi
}

cmd_watch() {
  [ "${BASH_VERSINFO[0]}" -ge 4 ] || exec /opt/homebrew/bin/bash "$SELF" watch
  local tick="${1:-5}" gitevery=4 n=0
  declare -A st since head_of br_of mt_of seen modeldrift_of agedflag_of label_of
  local now cols

  printf '\033[?25l'
  trap 'printf "\033[?25h\n"; exit 0' INT TERM

  while :; do
    now="$(date +%s)"
    cols="$("$TMUX_CMD" display -p -t "${TMUX_PANE:-}" '#{pane_width}' 2>/dev/null)"
    [ -n "$cols" ] || cols="$(tput cols 2>/dev/null || echo 80)"
    local rows_bound="" rows_unbound="" rows="" live=" "
    local -a map_pane_b=() map_win_b=() map_slug_b=()
    local -a map_pane_u=() map_win_u=() map_slug_u=()
    local target=$((cols * 80 / 100)) avail win_w=9 slug_w
    avail=$((target - 59))
    slug_w=$((avail - win_w))
    [ "$slug_w" -lt 20 ] && slug_w=20
    [ "$slug_w" -gt 60 ] && slug_w=60
    win_w=$((avail - slug_w))
    [ "$win_w" -lt 9 ] && win_w=9
    [ "$win_w" -gt 18 ] && win_w=18

    while IFS='|' read -r pane win slug branch state ctx cost path hash curmodel recmodel age cold; do
      [ -n "$pane" ] || continue
      local key="${slug:-$pane}" subj="${slug:-$win}"
      label_of[$key]="$subj"
      live="$live$key "

      if [ -z "${seen[$key]:-}" ]; then
        seen[$key]=1; since[$key]=$now; st[$key]="$state"
        [ "$n" -gt 0 ] && plog "$subj" window-opened "$win"
      fi
      if [ "${st[$key]}" != "$state" ]; then
        st[$key]="$state"; since[$key]=$now
        if [ "$state" = input ]; then plog "$subj" needs-input "$win"
        else plog "$subj" state "$state"; fi
      fi
      if [ -n "$branch" ] && [ "${br_of[$key]:-$branch}" != "$branch" ]; then
        plog "$subj" branch "$branch"
      fi
      br_of[$key]="$branch"

      local drift="no"
      if [ -n "$recmodel" ]; then
        [ "$curmodel" = "$recmodel" ] || drift="$curmodel≠$recmodel"
        if [ "${modeldrift_of[$key]:-$drift}" != "$drift" ] && [ "$drift" != "no" ]; then
          plog "$subj" model-drift "$drift"
        fi
        modeldrift_of[$key]="$drift"
      fi

      local f="$TODOS/$slug/TODO.md" m
      if [ -f "$f" ]; then
        m="$(stat -f %m "$f")"
        [ -n "${mt_of[$key]:-}" ] && [ "$m" != "${mt_of[$key]}" ] && plog "$subj" todo-updated ""
        mt_of[$key]="$m"
      fi

      if [ $((n % gitevery)) -eq 0 ] && [ -n "$path" ]; then
        local h
        h="$(git -C "$path" rev-parse --short HEAD 2>/dev/null)"
        if [ -n "$h" ]; then
          if [ -n "${head_of[$key]:-}" ] && [ "$h" != "${head_of[$key]}" ]; then
            plog "$subj" commit "$h $(git -C "$path" log -1 --pretty=%s 2>/dev/null | cut -c1-60)"
          fi
          head_of[$key]="$h"
        fi
      fi

      local glyph colour label
      case "$state" in
        working) glyph='●'; colour="$C_GRN"; label='working' ;;
        input)   glyph='▲'; colour="$C_YEL"; label='needs you' ;;
        *)       glyph='◌'; colour="$C_DIM"; label='idle' ;;
      esac
      local modeltxt modelcolour
      if [ -z "$recmodel" ]; then modeltxt="$curmodel"; modelcolour="$C_DIM"
      elif [ "$curmodel" = "$recmodel" ]; then modeltxt="$curmodel"; modelcolour="$C_DIM"
      else modeltxt="$curmodel≠$recmodel"; modelcolour="$C_YEL"; fi

      # session age: hygiene signal (recycle the window), not a cost signal
      local agemin=0 agecolour="$C_DIM" agetxt="$age"
      case "$age" in
        *h*) agemin=$(( ${age%%h*} * 60 + 10#$(printf '%s' "${age#*h}" | tr -dc '0-9' || echo 0) )) ;;
        *m)  agemin=$(( 10#$(printf '%s' "${age%m}" | tr -dc '0-9') )) ;;
      esac
      if   [ "$agemin" -ge 60 ]; then agecolour="$C_RED"; agetxt="$age!"
      elif [ "$agemin" -ge 45 ]; then agecolour="$C_YEL"; fi
      if [ "$agemin" -ge 60 ] && [ "${agedflag_of[$key]:-}" != "1" ]; then
        plog "$subj" session-old "$age"; agedflag_of[$key]=1
      fi
      # cold cache: the actual money. Shown in place of age colour when it is live.
      [ -n "$cold" ] && { agecolour="$C_YEL"; agetxt="$age ❄$cold"; }

      local todofield
      if [ -n "$slug" ]; then
        todofield="$(printf '%-*.*s' "$slug_w" "$slug_w" "$slug")"
      else
        todofield="$(printf '%-*s' "$slug_w" "")"
      fi

      local row
      row="$(printf ' %s%s%s %-*.*s %s %-10s %s%-13.13s%s %5s %9s %s%-13.13s%s %5s\n' \
        "$colour" "$glyph" "$C_RESET" "$win_w" "$win_w" "$win" "$todofield" "$label" \
        "$modelcolour" "$modeltxt" "$C_RESET" "$ctx" "$cost" \
        "$agecolour" "$agetxt" "$C_RESET" \
        "$(ago $((now - ${since[$key]})))")"$'\n'

      local winid; winid="$("$TMUX_CMD" display-message -p -t "$pane" '#{window_id}' 2>/dev/null)"
      if [ -n "$slug" ]; then
        rows_bound="$rows_bound$row"
        map_pane_b+=("$pane"); map_win_b+=("$winid"); map_slug_b+=("$slug")
      else
        rows_unbound="$rows_unbound$row"
        map_pane_u+=("$pane"); map_win_u+=("$winid"); map_slug_u+=("$win")
      fi
    done < <(pulse_scan)

    rows="$rows_bound$rows_unbound"
    local -a map_pane=("${map_pane_b[@]}" "${map_pane_u[@]}")
    local -a map_win=("${map_win_b[@]}" "${map_win_u[@]}")
    local -a map_slug=("${map_slug_b[@]}" "${map_slug_u[@]}")

    for key in "${!seen[@]}"; do
      case "$live" in
        *" $key "*) ;;
        *) plog "${label_of[$key]:-$key}" window-closed ""; unset "seen[$key]" "st[$key]" "label_of[$key]" ;;
      esac
    done

    local blocked=0 b
    for b in "${!st[@]}"; do [ "${st[$b]}" = input ] && blocked=$((blocked+1)); done

    local before_rows=2
    [ "$blocked" -gt 0 ] && before_rows=3
    local mapfile="$TODOS/.pulse-map" tmpmap i
    tmpmap="$(mktemp "$TODOS/.pulse-map.XXXXXX" 2>/dev/null)" && {
      for i in "${!map_slug[@]}"; do
        printf '%d\t%s\t%s\t%s\n' "$((before_rows + 1 + i))" "${map_win[$i]}" "${map_pane[$i]}" "${map_slug[$i]}"
      done > "$tmpmap"
      mv "$tmpmap" "$mapfile"
    }

    printf '\033[H\033[J'
    printf '%s╭ PULSE %s %s\n' "$C_CYN" "$(printf '─%.0s' $(seq 1 $((cols > 26 ? cols - 20 : 6))))" "$(date +%H:%M:%S)$C_RESET"
    [ "$blocked" -gt 0 ] && printf '%s  ▲ %d window%s waiting on you%s\n' \
      "$C_YEL$C_BOLD" "$blocked" "$([ "$blocked" -gt 1 ] && echo s)" "$C_RESET"
    printf '%s   %-*s %-*s %-10s %-13s %5s %9s %-13s %5s%s\n' "$C_DIM" "$win_w" WINDOW "$slug_w" TODO STATE MODEL CTX COST AGE FOR "$C_RESET"
    if [ -n "$rows" ]; then printf '%s' "$rows"; else printf '%s  no claude window is bound to a todo yet%s\n' "$C_DIM" "$C_RESET"; fi

    printf '\n%s  RECENT%s\n' "$C_DIM" "$C_RESET"
    if [ -s "$PULSE_LOG" ]; then
      tail -60 "$PULSE_LOG" | grep -v '|state|' | tail -8 | while IFS='|' read -r ts sl ev de; do
        printf '  %s%s%s  %-31.31s %s%s %s%s\n' \
          "$C_DIM" "${ts:11:5}" "$C_RESET" "$sl" "$C_BLU" "$ev" "${de:0:40}" "$C_RESET"
      done
    else
      printf '%s  nothing yet%s\n' "$C_DIM" "$C_RESET"
    fi

    printf '\n%s  %s · every %ss · ctrl-c stops%s\n' "$C_DIM" "$PULSE_LOG" "$tick" "$C_RESET"
    n=$((n + 1))
    sleep "$tick"
  done
}

cmd_pulse() {
  local since="${1:-}" all=0
  [ "$since" = "--all" ] && { all=1; since=""; }
  [ -f "$PULSE_LOG" ] || { echo "PULSE|empty"; return 0; }
  awk -F'|' -v since="$since" -v all="$all" '
    since != "" && $1 < since { next }
    all == 0 && $3 == "state" { next }
    { print "PULSE|" $0 }' "$PULSE_LOG" | tail -60
}

cmd_dash() {
  local target="${TMUX_PANE:-}"
  [ -n "$target" ] || die "not inside tmux"
  local existing
  existing="$("$TMUX_CMD" list-panes -F '#{pane_id}|#{@pulse}' 2>/dev/null | awk -F'|' '$2=="1"{print $1; exit}')"
  if [ -n "$existing" ]; then echo "DASH|exists|$existing"; return 0; fi
  local pane
  pane="$("$TMUX_CMD" split-window -v -l "${1:-30%}" -d -P -F '#{pane_id}' -t "$target" \
    -c "$TODOS" "$SELF watch")" || die "split-window failed"
  "$TMUX_CMD" set-option -p -t "$pane" @pulse 1
  "$TMUX_CMD" select-pane -t "$target"
  echo "DASH|opened|$pane"
}

cmd="${1:-standup}"; shift || true
case "$cmd" in
  standup) cmd_standup "${1:-}" ;;
  quote)   cmd_quote ;;
  board)   cmd_board ;;
  windows) cmd_windows ;;
  notes)   cmd_notes "${1:-$(default_since)}" ;;
  git)     cmd_git "${1:-$(default_since)}" ;;
  show)    cmd_show "${1:-}" ;;
  preview)  cmd_preview "${1:-}" ;;
  pick)     cmd_pick ;;
  popup)    cmd_popup "${1:-}" "${2:-}" ;;
  _picklist) pick_list ;;
  watch)    cmd_watch "${1:-}" ;;
  pulse)    cmd_pulse "${1:-}" ;;
  dash)     cmd_dash "${1:-}" ;;
  list)    cmd_list ;;
  open)    cmd_open "$@" ;;
  winddown) cmd_winddown "$@" ;;
  send)    cmd_send "$@" ;;
  close)   cmd_close "$@" ;;
  *) die "unknown command: $cmd" ;;
esac
