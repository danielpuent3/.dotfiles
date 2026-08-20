#!/usr/bin/env python3
"""PreToolUse on Write/Edit.

When a TODO.md is being updated and the session is past the checkpoint threshold, inject
the session's real numbers and a nudge to write a handoff. Never blocks: always exits 0,
and stays silent below the threshold.
"""
import sys, json, os, glob, time

WARN_MIN = 45

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# Fires for the Edit/Write tools and for Bash heredocs/redirects that write a TODO.md,
# since in auto mode todo updates usually come through Bash rather than Edit.
ti = d.get("tool_input") or {}
path = ti.get("file_path", "") or ""
cmd = ti.get("command", "") or ""
touching_todo = ("/.ai/todos/" in path and path.endswith("/TODO.md")) or (
    "TODO.md" in cmd
    and any(pat in cmd for pat in (">> ", ">>\"", ">> \"", "> /", "tee ", "sed -i"))
    and "/.ai/todos/" in cmd
)
if not touching_todo:
    sys.exit(0)

sid = d.get("session_id") or ""
tfile = d.get("transcript_path") or ""
if not tfile or not os.path.exists(tfile):
    hits = glob.glob(os.path.expanduser("~/.claude/projects/*/%s.jsonl" % sid)) if sid else []
    tfile = hits[0] if hits else ""
if not tfile or not os.path.exists(tfile):
    sys.exit(0)

st = os.stat(tfile)
now = time.time()
age_min = int((now - getattr(st, "st_birthtime", st.st_mtime)) / 60)
idle_min = int((now - st.st_mtime) / 60)
if age_min < WARN_MIN:
    sys.exit(0)

ctx = 0
try:
    with open(tfile, "rb") as fh:
        fh.seek(max(0, st.st_size - 400_000))
        for line in fh.read().decode("utf-8", "replace").splitlines():
            if '"usage"' not in line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get("type") != "assistant":
                continue
            u = (rec.get("message") or {}).get("usage") or {}
            if u:
                ctx = (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
                       + u.get("cache_creation_input_tokens", 0))
except Exception:
    pass

age_txt = "%dm" % age_min if age_min < 60 else "%dh%02dm" % (age_min // 60, age_min % 60)
bits = ["session is %s old" % age_txt]
if ctx:
    bits.append("context is ~%dK tokens" % (ctx // 1000))
if idle_min >= 5:
    bits.append("cache went cold %dm ago, so the next turn rebuilds it" % idle_min)

msg = (
    "Session checkpoint: " + ", ".join(bits) + ". "
    "Since a TODO is being updated, this is a natural stopping point. "
    "Write a `## Handoff (YYYY-MM-DD HH:MM)` section as the LAST section of the TODO with three "
    "short lines: what is Done, what is Open, what is Next, plus any file paths or branch names "
    "the next session needs. If a `## Handoff` section already exists, REPLACE it rather than "
    "adding a second one, so there is always exactly one and it is always current. The dated "
    "notes entries above it already carry the history. "
    "Then tell the user plainly that you recommend closing this window and "
    "reopening on the todo, so the next session starts on a small context. "
    "Say it once, do not repeat it later in the session, and do not block the work they asked for."
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse", "additionalContext": msg}}))
