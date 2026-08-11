#!/bin/sh
input=$(cat)

# --- Theme-aware Nord colors ---
theme=$(cat ~/.dotfiles/.theme 2>/dev/null || echo "dark")

if [ "$theme" = "light" ]; then
  # Polar Night / darker Frost for readability on light backgrounds
  C_CYAN='\033[38;2;94;129;172m'      # #5E81AC — branch (nord10)
  C_BLUE='\033[38;2;76;86;106m'       # #4C566A — model name (nord3)
  C_GREEN='\033[38;2;93;122;70m'      # #5D7A46 — insertions (darkened)
  C_RED='\033[38;2;191;97;106m'       # #BF616A — deletions
  C_YELLOW='\033[38;2;157;111;0m'     # #9D6F00 — cost (darkened)
  C_SNOW='\033[38;2;46;52;64m'        # #2E3440 — percentage / labels
  C_DIM='\033[38;2;216;222;233m'      # #D8DEE9 — bar empty blocks / separators
  C_PURPLE='\033[38;2;114;96;153m'    # #726099 — todo slug (darkened nord15)
else
  # Snow Storm / Frost for dark backgrounds
  C_CYAN='\033[38;2;136;192;208m'     # #88C0D0 — branch
  C_BLUE='\033[38;2;129;161;193m'     # #81A1C1 — model name
  C_GREEN='\033[38;2;163;190;140m'    # #A3BE8C — insertions
  C_RED='\033[38;2;191;97;106m'       # #BF616A — deletions
  C_YELLOW='\033[38;2;235;203;139m'   # #EBCB8B — cost
  C_SNOW='\033[38;2;216;222;233m'     # #D8DEE9 — percentage / labels
  C_DIM='\033[38;2;76;86;106m'        # #4C566A — bar empty blocks / separators
  C_PURPLE='\033[38;2;180;142;173m'   # #B48EAD — todo slug (nord15)
fi
C_RESET='\033[0m'

# --- payload ---
# One jq pass, unit-separated. A whitespace IFS would collapse consecutive
# delimiters and shift every field left when a value is absent.
US=$(printf '\037')
fields=$(echo "$input" | jq -r '[
  (.session_id // ""),
  (.workspace.current_dir // .cwd // "."),
  (.model.display_name // "unknown"),
  (.context_window.context_window_size // ""),
  (.context_window.used_percentage // ""),
  (.cost.total_cost_usd // ""),
  (.pr.number // ""),
  (.pr.review_state // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.rate_limits.seven_day.resets_at // "")
] | map(tostring) | join("\u001f")' 2>/dev/null)

IFS="$US" read -r session_id cwd model context_size used raw_cost \
  pr_num pr_state rl5 rl5_reset rl7 rl7_reset <<EOF
$fields
EOF

# --- bound todo ---
todo_slug=""
if [ -n "$session_id" ]; then
  todo_slug=$("$HOME/.local/bin/todo-session" get --session-id "$session_id" 2>/dev/null)
fi

# --- git diff stats (insertions/deletions vs HEAD, staged + unstaged) ---
branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
ins=""
del=""
if [ -n "$branch" ]; then
  numstat=$(git -C "$cwd" diff --numstat HEAD 2>/dev/null)
  if [ -n "$numstat" ]; then
    ins=$(echo "$numstat" | awk '{s+=$1} END {if(s>0) print s}')
    del=$(echo "$numstat" | awk '{s+=$2} END {if(s>0) print s}')
  fi
fi

# --- session cost ---
cost_str=""
if [ -n "$raw_cost" ]; then
  cost_str=$(printf '$%.2f' "$raw_cost")
fi

# --- model ---
if [ "$context_size" = "1000000" ]; then
  model="${model} 1M"
fi

# --- context window bar (10 blocks, colored by fullness) ---
bar=""
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  if [ "$used_int" -ge 85 ]; then
    C_BAR="$C_RED"
  elif [ "$used_int" -ge 60 ]; then
    C_BAR="$C_YELLOW"
  else
    C_BAR="$C_GREEN"
  fi
  filled=$(((used_int * 10 + 50) / 100))
  [ "$filled" -gt 10 ] && filled=10
  blocks=""
  i=0
  while [ "$i" -lt "$filled" ]; do
    blocks="${blocks}█"
    i=$((i + 1))
  done
  while [ "$i" -lt 10 ]; do
    blocks="${blocks}░"
    i=$((i + 1))
  done
  bar="${C_DIM}[${C_BAR}${blocks}${C_DIM}]${C_RESET} ${C_BAR}${used_int}%${C_RESET}"
fi

# --- rate limit (whichever window is the tighter constraint, once it matters) ---
rl_seg=""
rl5_int=0
rl7_int=0
[ -n "$rl5" ] && rl5_int=$(printf '%.0f' "$rl5")
[ -n "$rl7" ] && rl7_int=$(printf '%.0f' "$rl7")
if [ "$rl5_int" -ge "$rl7_int" ]; then
  rl_int="$rl5_int"; rl_label="5h"; rl_reset="$rl5_reset"
else
  rl_int="$rl7_int"; rl_label="7d"; rl_reset="$rl7_reset"
fi
if [ "$rl_int" -ge 50 ]; then
  if [ "$rl_int" -ge 90 ]; then
    C_RL="$C_RED"
  elif [ "$rl_int" -ge 75 ]; then
    C_RL="$C_YELLOW"
  else
    C_RL="$C_SNOW"
  fi
  rl_filled=$(((rl_int * 5 + 50) / 100))
  [ "$rl_filled" -gt 5 ] && rl_filled=5
  rl_blocks=""
  i=0
  while [ "$i" -lt "$rl_filled" ]; do
    rl_blocks="${rl_blocks}▓"
    i=$((i + 1))
  done
  while [ "$i" -lt 5 ]; do
    rl_blocks="${rl_blocks}░"
    i=$((i + 1))
  done
  rl_seg="${C_DIM}${rl_label}${C_RESET} ${C_RL}${rl_blocks} ${rl_int}%${C_RESET}"
  if [ "$rl_int" -ge 90 ] && [ -n "$rl_reset" ]; then
    reset_hhmm=$(date -r "$rl_reset" +%H:%M 2>/dev/null)
    [ -n "$reset_hhmm" ] && rl_seg="${rl_seg} ${C_DIM}→ ${reset_hhmm}${C_RESET}"
  fi
fi

# --- PR badge ---
pr_seg=""
if [ -n "$pr_num" ]; then
  case "$pr_state" in
    approved)          C_PR="$C_GREEN" ;;
    changes_requested) C_PR="$C_RED" ;;
    draft)             C_PR="$C_DIM" ;;
    *)                 C_PR="$C_YELLOW" ;;
  esac
  pr_seg="${C_PR}#${pr_num}${C_RESET}"
fi

# --- assemble ---
SEP="${C_DIM}  ${C_RESET}"
out=""

append() {
  [ -z "$1" ] && return
  if [ -n "$out" ]; then
    out="${out}${SEP}$1"
  else
    out="$1"
  fi
}

[ -n "$todo_slug" ] && append "${C_PURPLE}📝 ${todo_slug}${C_RESET}"
[ -n "$branch" ] && append "${C_CYAN}${branch}${C_RESET}"
append "$pr_seg"

if [ -n "$ins" ] || [ -n "$del" ]; then
  diff_colored=""
  [ -n "$ins" ] && diff_colored="${C_GREEN}+${ins}${C_RESET}"
  if [ -n "$del" ]; then
    [ -n "$diff_colored" ] && diff_colored="${diff_colored} "
    diff_colored="${diff_colored}${C_RED}-${del}${C_RESET}"
  fi
  append "$diff_colored"
fi

[ -n "$cost_str" ] && append "${C_YELLOW}${cost_str}${C_RESET}"

if [ -n "$bar" ]; then
  append "${C_BLUE}${model}${C_RESET}  ${bar}"
else
  append "${C_BLUE}${model}${C_RESET}"
fi

append "$rl_seg"

printf "%b" "$out"
