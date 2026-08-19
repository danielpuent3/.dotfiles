#!/usr/bin/env bash
#
# links.sh — every URL the current session can reach, one per line.
#
# Output is KEY|field|value lines, cheap to parse:
#   TODO|<slug>                  the todo these links came from
#   LINK|<frontmatter field>|<url>
#   PR|<branch>|<url>            from `gh`, only when the todo names no PR
#   NOTE|<text>                  why a source gave nothing
#
# Matching is deliberately not done here. This dumps candidates and the skill
# picks; a scoring function here would mean an alias table to keep in sync.
#
# Any frontmatter value that looks like a URL is emitted, whatever field holds
# it, so a field added to SPEC.md later needs no change here.

set -uo pipefail

TODOS_DIR="${TODOS_DIR:-$HOME/.ai/todos}"

fm() {
    awk -v k="$2" '
        NR==1 && $0=="---" { inf=1; next }
        inf && $0=="---"   { exit }
        inf {
            p = k ": "
            if (substr($0, 1, length(p)) == p) {
                v = substr($0, length(p)+1)
                gsub(/^"|"$/, "", v)
                print v; exit
            }
        }' "$1"
}

urls() {
    awk '
        function emit(k, v,   s) {
            s = v
            gsub(/^[ \t"]+|[ \t"]+$/, "", s)
            if (s ~ /^https?:\/\//) print "LINK|" k "|" s
        }
        NR==1 && $0=="---" { inf=1; next }
        inf && $0=="---"   { exit }
        !inf { next }
        /^[a-z_]+:/ {
            key = $0; sub(/:.*/, "", key)
            rest = $0; sub(/^[a-z_]+:[ \t]*/, "", rest)
            if (rest == "" || rest == "[]") next
            gsub(/^\[|\]$/, "", rest)
            n = split(rest, parts, ",")
            for (i = 1; i <= n; i++) emit(key, parts[i])
            next
        }
        /^[ \t]+- / { v = $0; sub(/^[ \t]+- /, "", v); emit(key, v) }
    ' "$1"
}

slug="$(todo-session get 2>/dev/null)"
todo=""
found_pr=0

if [ -n "$slug" ] && [ -f "$TODOS_DIR/$slug/TODO.md" ]; then
    todo="$TODOS_DIR/$slug/TODO.md"
    printf 'TODO|%s\n' "$slug"
    out="$(urls "$todo")"
    [ -n "$out" ] && printf '%s\n' "$out"
    grep -q '^LINK|pr_urls|' <<<"$out" && found_pr=1
    [ -z "$out" ] && printf 'NOTE|%s holds no links in frontmatter\n' "$slug"
else
    printf 'NOTE|no todo bound to this session\n'
fi

# gh only backstops a PR the todo has not recorded yet; it is a network call.
if [ "$found_pr" -eq 0 ]; then
    dir=""
    [ -n "$todo" ] && dir="$(fm "$todo" project_directory)"
    [ -d "${dir:-}" ] || dir="$PWD"
    if pr="$(cd "$dir" && gh pr view --json url,headRefName \
                 -q '"PR|" + .headRefName + "|" + .url' 2>/dev/null)" \
       && [ -n "$pr" ]; then
        printf '%s\n' "$pr"
    else
        printf 'NOTE|no open PR on the current branch in %s\n' "${dir/#$HOME/\~}"
    fi
fi
