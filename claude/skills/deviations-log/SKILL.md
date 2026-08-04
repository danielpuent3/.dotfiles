---
name: deviations-log
description: Opt-in. During longer implementation work, keep an implementation-notes.md; when an edge case or ambiguity comes up, pick the conservative option, log it under a "Deviations" heading with the reasoning, and keep going instead of stopping to ask. Not default behavior; invoke only when the user asks, e.g. "keep a deviations log", "log deviations", "implementation notes".
---

# deviations-log

## Purpose

Keep momentum on longer implementation tasks without silently making judgment calls the user never sees. Instead of stopping for every ambiguity, pick the safe option, write down why, and let the user review the whole list at once instead of one interruption at a time.

## When to run this

Only when explicitly invoked, for implementation work long enough that stopping on every ambiguity would be disruptive.

## Steps

### 1. Create the notes file

At the start of the task, create `implementation-notes.md` in the project root (or the directory the user specifies) with a `## Deviations` heading. If the file already exists, append to it — don't overwrite prior entries.

### 2. Keep working through ambiguity

When you hit an edge case, an underspecified requirement, or a choice between reasonable options:
- Pick the conservative option: the one that's safest to change later, least surprising to existing behavior, and least likely to cause data loss or a breaking change.
- Do not stop to ask. Log it and continue.

### 3. Log the deviation

Under `## Deviations`, add an entry for each one:

```markdown
- **[file:line or component]** — [what was ambiguous]. Chose: [the conservative option]. Reasoning: [why this option, one line].
```

Keep entries short. The log is a record for review, not a design doc.

### 4. Surface the log at the end

When the implementation is done, point the user at `implementation-notes.md` and call out any deviation where the conservative choice might not match what they actually wanted — don't make them read the whole log to find the ones that matter.

## Notes

- "Conservative" means reversible and low-blast-radius, not necessarily the simplest to code.
- If an ambiguity is high-stakes enough that guessing wrong would be expensive to unwind (data migrations, auth boundaries, billing logic), stop and ask instead of logging a guess — this skill is for keeping flow on low-stakes calls, not for skipping judgment on high-stakes ones.
