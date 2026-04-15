#!/bin/sh
input=$(cat)

# --- Nord color palette (true-color ANSI) ---
# Frost
C_CYAN='\033[38;2;136;192;208m'    # #88C0D0 — branch
C_BLUE='\033[38;2;129;161;193m'    # #81A1C1 — model name
C_DEEP='\033[38;2;94;129;172m'     # #5E81AC — bar filled blocks
# Aurora
C_GREEN='\033[38;2;163;190;140m'   # #A3BE8C — insertions
C_RED='\033[38;2;191;97;106m'      # #BF616A — deletions
C_YELLOW='\033[38;2;235;203;139m'  # #EBCB8B — cost
# Snow Storm
C_SNOW='\033[38;2;216;222;233m'    # #D8DEE9 — percentage / labels
# Polar Night
C_DIM='\033[38;2;76;86;106m'       # #4C566A — bar empty blocks / separators
C_RESET='\033[0m'

# --- cwd (for git commands) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')

# --- git branch ---
branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)

# --- git diff stats (insertions/deletions vs HEAD, staged + unstaged) ---
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
raw_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$raw_cost" ]; then
  cost_str=$(printf '$%.2f' "$raw_cost")
fi

# --- model ---
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')

# --- context window bar (10 blocks) ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
bar_filled=""
bar_empty=""
if [ -n "$used" ]; then
  filled=$(printf "%.0f" "$(echo "$used * 10 / 100" | bc -l)")
  empty_count=$((10 - filled))
  i=0
  while [ "$i" -lt "$filled" ]; do
    bar_filled="${bar_filled}█"
    i=$((i + 1))
  done
  i=0
  while [ "$i" -lt "$empty_count" ]; do
    bar_empty="${bar_empty}░"
    i=$((i + 1))
  done
fi

# --- separator helper ---
SEP="${C_DIM}  ${C_RESET}"

# --- assemble with Nord colors ---
out=""

# git branch
if [ -n "$branch" ]; then
  out="${C_CYAN}${branch}${C_RESET}"
fi

# diff stats
if [ -n "$ins" ] || [ -n "$del" ]; then
  diff_colored=""
  [ -n "$ins" ] && diff_colored="${C_GREEN}+${ins}${C_RESET}"
  if [ -n "$del" ]; then
    [ -n "$diff_colored" ] && diff_colored="${diff_colored} "
    diff_colored="${diff_colored}${C_RED}-${del}${C_RESET}"
  fi
  if [ -n "$out" ]; then
    out="${out}${SEP}${diff_colored}"
  else
    out="${diff_colored}"
  fi
fi

# cost
if [ -n "$cost_str" ]; then
  colored_cost="${C_YELLOW}${cost_str}${C_RESET}"
  if [ -n "$out" ]; then
    out="${out}${SEP}${colored_cost}"
  else
    out="${colored_cost}"
  fi
fi

# model + context bar
if [ -n "$used" ]; then
  ctx_bar="${C_DIM}[${C_DEEP}${bar_filled}${C_DIM}${bar_empty}${C_DIM}]${C_RESET} ${C_SNOW}$(printf '%.0f' "$used")%${C_RESET}"
  model_ctx="${C_BLUE}${model}${C_RESET}  ${ctx_bar}"
else
  model_ctx="${C_BLUE}${model}${C_RESET}"
fi
if [ -n "$out" ]; then
  out="${out}${SEP}${model_ctx}"
else
  out="${model_ctx}"
fi

printf "%b" "$out"
