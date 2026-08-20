#!/usr/bin/env bash
# PreToolUse guard for Bash. exit 2 blocks the call and returns stderr to the agent.
# Matching is anchored at command position and does not cross shell separators, so a later
# flag in an unrelated command in the same line cannot trigger an earlier rule.

payload=$(cat)
cmd=$(printf '%s' "$payload" | /usr/bin/python3 -c \
  'import sys,json
try: print((json.load(sys.stdin).get("tool_input") or {}).get("command",""))
except Exception: print("")' 2>/dev/null)
[ -z "$cmd" ] && exit 0

block() {
  printf 'BLOCKED by block-destructive.sh: %s\n' "$1" >&2
  printf 'On the destructive-operation block list. Do not work around it. Ask the user to run it.\n' >&2
  exit 2
}

POS='(^|[;&|]|[[:cntrl:]])[[:space:]]*'
SEG='[^;&|]*'   # stays inside one command segment

m() { printf '%s' "$cmd" | grep -Eq "$POS$1"; }

m "git[[:space:]]+${SEG}reset[[:space:]]+${SEG}--hard"      && block 'git reset --hard'
m "git[[:space:]]+${SEG}clean[[:space:]]+-[a-zA-Z]*f"       && block 'git clean -f'
m "git[[:space:]]+${SEG}push[[:space:]]+${SEG}--force"      && block 'git push --force'
m "git[[:space:]]+${SEG}push[[:space:]]+${SEG}-f([[:space:]]|$)" && block 'git push -f'
m 'terraform[[:space:]]+destroy'                            && block 'terraform destroy'
m 'aws[[:space:]]+s3[[:space:]]+rm'                         && block 'aws s3 rm'
m "kubectl[[:space:]]+${SEG}delete"                         && block 'kubectl delete'

# rm -r -f: block only genuinely dangerous targets. Relative paths inside a repo are
# recoverable via git and are routine here (vendor, tmp, build artifacts), so they pass.
if printf '%s' "$cmd" | grep -Eq "${POS}rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*f|${POS}rm[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*[rR]"; then
  targets=$(printf '%s' "$cmd" \
    | grep -Eo "rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)+[^;&|]*" \
    | sed -E 's/rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)+//')
  for t in $targets; do
    case "$t" in
      [0-9]'>'*|'>'*|'<'*|'2>'*|*/dev/null) continue ;;          # redirections, not targets
      /tmp/*|/private/tmp/*|/var/folders/*) continue ;;          # temp dirs are fine
      '~/.cache/'*|'$HOME/.cache/'*) continue ;;                  # user cache is disposable
      '/'|'/*'|'~'|'~/'|'$HOME'|'$HOME/'|'.'|'./'|'..'|'../'|'*') block "rm -rf on '$t'" ;;
      /*|'~/'*|'$HOME/'*) block "rm -rf on absolute path '$t'" ;; # absolute outside temp
      *..*) block "rm -rf with parent traversal '$t'" ;;
    esac
  done
fi
exit 0
