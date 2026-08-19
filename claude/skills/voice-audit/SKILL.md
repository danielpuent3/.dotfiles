---
name: voice-audit
description: Audit the /voice skill against reality by comparing what Claude drafted with what the user actually sent. Two modes. Capture mode records one draft/sent pair from the current session and classifies the differences. Review mode tallies the corpus and proposes concrete edits to `~/.claude/skills/voice/SKILL.md` for any pattern that recurs. Trigger on "audit my voice", "capture this", "log this edit", "what did I change", "review my voice audit", "what's ready to promote".
---

# voice-audit

## Purpose

The `/voice` skill is a guess about how the user writes. This skill measures the guess. Every time Claude drafts text and the user edits it before sending, the edit is a signal. Capture enough of them and the real patterns separate from the one-offs, and only then is it worth touching the voice skill.

The backing tool lives at `~/.ai/voice-audit/bin/voice-audit`. It stores one file per draft/sent pair under `~/.ai/voice-audit/pairs/`, tallies the classified differences, and reports which patterns recur often enough to act on. This skill is the human judgement around that tool: reading the diff correctly, tagging it honestly, and never editing the voice skill on a single data point.

## The taxonomy (the whole point)

Every difference between a draft and what was sent falls into one of three buckets. Only one of them is evidence the voice skill needs changing.

- **`content`** — the user changed facts, scope, or emphasis. Added a detail, cut a paragraph, softened a claim, corrected something wrong. This is not a voice signal. It tells you nothing about style.
- **`compliance`** — Claude broke a rule the voice skill already states. An em dash slipped in, a "leverage" got through. This is an enforcement gap, not a missing rule. The fix is to apply the existing skill better, not to add to it.
- **`voice:<pattern>`** — the skill had no opinion and the user did. Claude wrote something the rules permit, and the user changed it anyway on style grounds. This is the only promotable kind. The `<pattern>` slug names the recurring habit, e.g. `voice:cut-greeting`, `voice:lowercase-headers`, `voice:no-bullet-for-two`.

Tag honestly. Calling a content edit a voice signal poisons the corpus. Calling a voice signal a compliance miss buries a real gap. When a single edit spans two buckets, write two delta lines.

## Mode 1: Capture

Triggered when the user pastes text they actually sent after Claude gave them a draft, or says "capture this" / "log this edit". Runs in the same session where the draft was produced, so the draft is in this session's own transcript.

1. **Find the draft.** Run `~/.ai/voice-audit/bin/voice-audit drafts -n 10` to list recent assistant drafts from this session, newest last. Identify which one the user's sent text corresponds to. If it is not obviously the most recent, ask or use the timestamps and previews to pin it down.
2. **Pull it verbatim.** Run `~/.ai/voice-audit/bin/voice-audit drafts --full N` where `N` is the position from the end (1 = most recent). This prints the full draft text. Do not retype or clean it. The point is to record exactly what was produced.
3. **Create the pair.** Run `~/.ai/voice-audit/bin/voice-audit new <slug> --channel <slack|pr|commit|slite|email|other>`. Pick a short slug describing the message. The tool prints the path of the new pair file.
4. **Fill it in.** Edit the pair file:
   - **Context** — one line: what the message was, who it went to, what it needed to do.
   - **Draft** — paste the verbatim draft from step 2.
   - **Sent** — paste the verbatim text the user gave you. Do not tidy it.
   - **Deltas** — one line per difference, each tagged per the taxonomy. Diff the two texts carefully. A dropped word is a delta. A reordered clause is a delta. Reach for an existing pattern slug from `CANDIDATES.md` before inventing a new one; a near-duplicate slug splits one real signal into two counts that never reach the threshold.
5. **Update the tallies.** Run `~/.ai/voice-audit/bin/voice-audit tally`. This regenerates `CANDIDATES.md` and `INDEX.md`. Report back briefly: what patterns you tagged and whether any crossed the threshold.

Do not propose voice-skill edits during capture. Capture records; it does not act.

## Mode 2: Review

Triggered by "review my voice audit", "what's ready to promote", or similar.

1. Run `~/.ai/voice-audit/bin/voice-audit tally` to refresh, then read `~/.ai/voice-audit/CANDIDATES.md`.
2. For any pattern in the "Ready to promote" section (at or over the threshold, default 3 distinct pairs), open the cited pair files and confirm the tag was applied consistently and honestly. A pattern is only real if the pairs actually show the same habit, not three loosely related edits filed under one slug.
3. For each confirmed pattern, draft a concrete rule to add to `~/.claude/skills/voice/SKILL.md`, phrased in the same terse style as the existing rules, and cite the verbatim pair examples that justify it.
4. Present the proposed diff and stop. Do not write to the voice skill without an explicit "yes" or "apply it" from the user. This mirrors the approval gate in [[sync-voice-from-slack]].
5. On approval, edit `~/.claude/skills/voice/SKILL.md`, then note in the relevant pair files (or a short log line) that the pattern was promoted, so it is not re-proposed next review.

Patterns below the threshold live in the "Watching" section. Mention them if asked, but do not act on them. The threshold exists so a single stylistic whim does not become a permanent rule.

## Guardrails

- **Never write to `~/.claude/skills/voice/SKILL.md` without explicit approval.** Proposing is free; writing needs a yes.
- **Verbatim means verbatim.** Never clean, reformat, or "improve" either the draft or the sent text before recording. The corpus is worthless if it records a tidied version of what happened.
- **The tool counts pairs, not mentions.** Tagging the same pattern five times inside one pair still counts as one pair toward the threshold. This is deliberate; do not try to game it.
- **When capture and review would collide, capture first.** Recording a fresh pair is cheap and time-sensitive (the draft ages out of easy reach); promotion can always wait.

## Tool reference

```
voice-audit drafts [-n N] [--session-id ID] [--full I]   list or print session drafts
voice-audit new <slug> [--channel CH] [--date YYYY-MM-DD] create a pair file
voice-audit tally                                         regenerate CANDIDATES.md and INDEX.md
voice-audit list                                          list pairs
voice-audit ready [--threshold N]                         patterns at or over the threshold
```

Env: `VOICE_AUDIT_DIR` (default `~/.ai/voice-audit`), `VOICE_AUDIT_THRESHOLD` (default 3).
