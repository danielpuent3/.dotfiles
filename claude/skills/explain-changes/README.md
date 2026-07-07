# explain-changes

A Claude Code skill that walks through code changes the way a human would in a PR review: one diff at a time, explaining the *why* before the *what*, pausing between sections so you can ask questions, queue feedback, or apply fixes inline.

Works on any language or stack. Stack-specific subsets (e.g. Laravel/PHP) are layered on top of a generic structure.

## When it triggers

Say any of:

- "explain changes"
- "walk me through this"
- "review this like a PR"
- "explain what I just did"
- or paste a PR URL / number and ask to review it

## What it does

1. **Detects mode** based on what you give it:
   - **PR URL or number** → *Review mode*: queues comments as you go, posts them at the end via `gh pr review`.
   - **Open PR on current branch** → asks whether you're reviewing or walking through your own work.
   - **No open PR** → *Walkthrough mode*: applies inline cleanups you approve, commits at the end.
2. **Orders the diffs by narrative**, not file system. Entry point → main logic → supporting code → integrations → contracts → adapters → tests → tooling → misc.
3. **Shows the diff first**, then explains it. Never explains without showing the code. Never elides with `...`.
4. **Pauses after each section** with a prompt:
   - Continue
   - Ask a question / leave a comment (mode-dependent)
   - Capture a skill improvement
   - Something else

## The two modes

### Walkthrough mode

For your own work. The goal is understanding and cleanup.

- Spots issues as it goes (naming, structure, dead code, security, perf, missing tests).
- Offers to apply fixes inline.
- Wraps up with a summary of inline changes and a prompt to commit.

### Review mode

For someone else's PR. The goal is feedback.

- Never applies changes — queues them as review comments instead.
- Phrases comments as *yours* to send, not the assistant's.
- Wraps up by showing the queued comments for editing, then posts via `gh pr review`.

## Customizing it

The skill self-edits. Pick **"Skill notes"** at any prompt during a walkthrough to capture an improvement — Claude will update `SKILL.md` before resuming.

## Files

- `SKILL.md` — the skill definition Claude reads at runtime.
- `README.md` — this file (for humans).
