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
    printf 'TODO|%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$slug" \
      "$(fm "$f" status)" \
      "$(fm "$f" priority)" \
      "$(fm "$f" type)" \
      "$(fm "$f" created)" \
      "$(date -r "$f" +%F)" \
      "$(fmlist "$f" branches)" \
      "$(fmlist "$f" pr_urls)"
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

cmd_open() {
  local slug="" name="" prompt="" switch=0 force=0 dir=""
  slug="${1:-}"; shift || true
  [ -n "$slug" ] || die "usage: orch.sh open <slug> [--name X] [--prompt X] [--switch] [--force] [--dir X]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --name)   name="$2"; shift 2 ;;
      --prompt) prompt="$2"; shift 2 ;;
      --dir)    dir="$2"; shift 2 ;;
      --switch) switch=1; shift ;;
      --force)  force=1; shift ;;
      *) die "unknown option: $1" ;;
    esac
  done

  local d; d="$(slug_dir "$slug")" || exit 1
  [ -n "$dir" ] || dir="$(fm "$d/TODO.md" project_directory)"
  [ -d "$dir" ] || die "project_directory does not exist: $dir"
  "$TMUX_CMD" has-session -t 0 2>/dev/null || "$TMUX_CMD" list-sessions >/dev/null 2>&1 || die "no tmux server running"

  local existing
  existing="$("$TMUX_CMD" list-windows -a -F '#{window_id}|#{@todo}|#{window_index}|#{window_name}' 2>/dev/null \
    | awk -F'|' -v s="$slug" '$2==s { print $1 "|" $3 "|" $4; exit }')"
  if [ -n "$existing" ] && [ "$force" -eq 0 ]; then
    [ "$switch" -eq 1 ] && "$TMUX_CMD" select-window -t "${existing%%|*}"
    echo "EXISTS|$existing|$slug"
    return 0
  fi

  [ -n "$name" ] || name="$(printf '%s' "$slug" | cut -c1-14)"

  local uuid
  uuid="$(uuidgen | tr 'A-Z' 'a-z')"
  mkdir -p "$SESSIONS"
  printf '%s' "$slug" > "$SESSIONS/$uuid"

  [ -n "$prompt" ] || prompt="You are picking up todo \`$slug\`. Run: todo-session set $slug. Then read $d/TODO.md, check git branch and status in $dir against its branches field, and give me a five-line status plus the single next action. Do not change anything until I confirm."

  local winid
  winid="$("$TMUX_CMD" new-window -d -P -F '#{window_id}' -n "$name" -c "$dir")" || die "tmux new-window failed"
  "$TMUX_CMD" set-option -w -t "$winid" @todo "$slug"
  "$TMUX_CMD" send-keys -t "$winid" "$CLAUDE_BIN --session-id $uuid $(printf '%q' "$prompt")" Enter
  [ "$switch" -eq 1 ] && "$TMUX_CMD" select-window -t "$winid"

  local idx
  idx="$("$TMUX_CMD" display-message -p -t "$winid" '#{window_index}')"
  echo "OPENED|$winid|$idx|$name|$slug|$dir|$uuid"
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

  local st pr ty dir br prs win
  st="$(fm "$f" status)"; pr="$(fm "$f" priority)"; ty="$(fm "$f" type)"
  dir="$(fm "$f" project_directory)"
  br="$(fmlist "$f" branches)"; prs="$(fmlist "$f" pr_urls)"
  win="$(window_for "$slug")"

  printf '%s%s%s\n' "$C_BOLD" "$(fm "$f" title)" "$C_RESET"
  printf '%s%s · %s · %s%s\n\n' "$C_DIM" "$st" "$pr" "$ty" "$C_RESET"
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
  local list sel slug
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
    --header=$'enter open · ctrl-o open+switch · ctrl-x close window · ctrl-r reload\n' \
    --expect=ctrl-o,ctrl-x)" || return 0

  local key; key="$(head -1 <<<"$sel")"
  slug="$(sed -n '2p' <<<"$sel" | cut -f1)"
  [ -n "$slug" ] || return 0

  case "$key" in
    ctrl-x) cmd_close "$slug" ;;
    ctrl-o) cmd_open "$slug" --switch ;;
    *)      cmd_open "$slug" ;;
  esac
}

cmd_popup() {
  local w="${1:-92%}" h="${2:-86%}"
  "$TMUX_CMD" display-popup -E -w "$w" -h "$h" \
    -T ' todo orchestrator ' \
    "$SELF pick; printf '\\n  press any key '; read -rsn1" >/dev/null 2>&1 &
  disown 2>/dev/null
  echo "POPUP|opened"
}


# ── pulse: live view of every claude window bound to a todo ───────────────────
#
# Reads state straight off each pane's Claude Code status line, which already
# carries the bound todo, branch, cost and context use. Transitions are appended
# to $PULSE_LOG so the orchestrator can read the day back without watching it.

plog() { printf '%s|%s|%s|%s\n' "$(date +%FT%T)" "$1" "$2" "${3:-}" >> "$PULSE_LOG"; }

pulse_scan() {   # pane|window|slug|branch|state|ctx|cost|path|hash
  local p tail sline slug branch cost ctx state win
  for p in $("$TMUX_CMD" list-panes -a -F '#{pane_id}' 2>/dev/null); do
    tail="$("$TMUX_CMD" capture-pane -p -t "$p" 2>/dev/null | tail -25)"
    case "$tail" in *"📝 "*) ;; *) continue ;; esac
    sline="$(grep -F '📝 ' <<<"$tail" | tail -1)"
    slug="$(sed -n 's/.*📝 \([^ ][^ ]*\).*/\1/p' <<<"$sline")"
    [ -n "$slug" ] || continue
    branch="$(sed 's/.*📝 [^ ][^ ]*  *//; s/  .*//; s/ *[✓✗↑↓*].*//' <<<"$sline")"
    cost="$(grep -o '\$[0-9][0-9.,]*' <<<"$sline" | head -1)"
    ctx="$(grep -o '[0-9][0-9]*%' <<<"$sline" | tail -1)"
    if grep -q 'esc to interrupt' <<<"$tail"; then state=working
    elif grep -qE 'Do you want|Would you like|Proceed\?|\(y/n\)|^ *❯ *[0-9]\.|^ *[0-9]\. Yes|Press enter to' <<<"$tail"; then state=input
    else state=idle; fi
    win="$("$TMUX_CMD" display -p -t "$p" '#{window_name}' 2>/dev/null)"
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$p" "$win" "$slug" "$branch" "$state" "${ctx:-–}" "${cost:-–}" \
      "$("$TMUX_CMD" display -p -t "$p" '#{pane_current_path}' 2>/dev/null)" \
      "$(cksum <<<"$tail" | cut -d' ' -f1)"
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
  declare -A st since head_of br_of mt_of seen
  local now cols

  printf '\033[?25l'
  trap 'printf "\033[?25h\n"; exit 0' INT TERM

  while :; do
    now="$(date +%s)"
    cols="$(tput cols 2>/dev/null || echo 80)"
    local rows="" live=" "

    while IFS='|' read -r pane win slug branch state ctx cost path hash; do
      [ -n "$slug" ] || continue
      live="$live$slug "

      if [ -z "${seen[$slug]:-}" ]; then
        seen[$slug]=1; since[$slug]=$now; st[$slug]="$state"
        [ "$n" -gt 0 ] && plog "$slug" window-opened "$win"
      fi
      if [ "${st[$slug]}" != "$state" ]; then
        st[$slug]="$state"; since[$slug]=$now
        if [ "$state" = input ]; then plog "$slug" needs-input "$win"
        else plog "$slug" state "$state"; fi
      fi
      if [ -n "$branch" ] && [ "${br_of[$slug]:-$branch}" != "$branch" ]; then
        plog "$slug" branch "$branch"
      fi
      br_of[$slug]="$branch"

      local f="$TODOS/$slug/TODO.md" m
      if [ -f "$f" ]; then
        m="$(stat -f %m "$f")"
        [ -n "${mt_of[$slug]:-}" ] && [ "$m" != "${mt_of[$slug]}" ] && plog "$slug" todo-updated ""
        mt_of[$slug]="$m"
      fi

      if [ $((n % gitevery)) -eq 0 ] && [ -n "$path" ]; then
        local h
        h="$(git -C "$path" rev-parse --short HEAD 2>/dev/null)"
        if [ -n "$h" ]; then
          if [ -n "${head_of[$slug]:-}" ] && [ "$h" != "${head_of[$slug]}" ]; then
            plog "$slug" commit "$h $(git -C "$path" log -1 --pretty=%s 2>/dev/null | cut -c1-60)"
          fi
          head_of[$slug]="$h"
        fi
      fi

      local glyph colour label
      case "$state" in
        working) glyph='●'; colour="$C_GRN"; label='working' ;;
        input)   glyph='▲'; colour="$C_YEL"; label='needs you' ;;
        *)       glyph='◌'; colour="$C_DIM"; label='idle' ;;
      esac
      rows="$rows$(printf ' %s%s%s %-9.9s %-31.31s %-10s %5s %9s %5s\n' \
        "$colour" "$glyph" "$C_RESET" "$win" "$slug" "$label" "$ctx" "$cost" \
        "$(ago $((now - ${since[$slug]})))")"$'\n'
    done < <(pulse_scan)

    for slug in "${!seen[@]}"; do
      case "$live" in *" $slug "*) ;; *) plog "$slug" window-closed ""; unset "seen[$slug]" "st[$slug]" ;; esac
    done

    local blocked=0 b
    for b in "${!st[@]}"; do [ "${st[$b]}" = input ] && blocked=$((blocked+1)); done

    printf '\033[H\033[J'
    printf '%s╭ PULSE %s %s\n' "$C_CYN" "$(printf '─%.0s' $(seq 1 $((cols > 26 ? cols - 20 : 6))))" "$(date +%H:%M:%S)$C_RESET"
    [ "$blocked" -gt 0 ] && printf '%s  ▲ %d window%s waiting on you%s\n' \
      "$C_YEL$C_BOLD" "$blocked" "$([ "$blocked" -gt 1 ] && echo s)" "$C_RESET"
    printf '%s   %-9s %-31s %-10s %5s %9s %5s%s\n' "$C_DIM" WINDOW TODO STATE CTX COST FOR "$C_RESET"
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
  pane="$("$TMUX_CMD" split-window -h -l "${1:-38%}" -d -P -F '#{pane_id}' -t "$target" \
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
  send)    cmd_send "$@" ;;
  close)   cmd_close "$@" ;;
  *) die "unknown command: $cmd" ;;
esac
