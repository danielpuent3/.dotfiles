---
name: interview-mode
description: Opt-in. Interview the user one question at a time to pin down requirements before implementing, prioritizing questions whose answer would change the architecture or data model. Not default behavior; invoke only when the user asks, e.g. "interview me", "interview mode", "ask me one at a time".
---

# interview-mode

## Purpose

Requirements gathering through a real back-and-forth instead of a wall of upfront questions or a plan built on guesses. One question, one answer, repeat until the design is actually settled.

## When to run this

Only when explicitly invoked, typically before starting on a nontrivial feature or change where the requirements are underspecified.

## Rules

- **One question at a time.** Never batch questions into a list. Ask, wait for the answer, then ask the next one.
- **Order by leverage.** Ask the question whose answer would most change the architecture or data model first. Questions that only affect wording, naming, or minor UX come last, if at all.
- **Adapt on the fly.** Let each answer reshape the next question. Don't run through a fixed script.
- **Stop when done.** Stop asking once further questions wouldn't change the design — don't pad the interview to seem thorough.

## Steps

### 1. Form the first question

From the initial ask, identify the single biggest open unknown — usually something about scope, data shape, ownership, or a constraint that would force a different architecture depending on the answer. Ask only that.

### 2. Iterate

After each answer:
- Update your working model of the design.
- Check whether the answer resolved or exposed other open questions.
- Ask the next highest-leverage question, or state that you have enough to proceed.

### 3. Recognize the stopping point

Stop when remaining unknowns are implementation details you'd resolve the same way regardless of the answer, or details cheap to change later. Say plainly: "I have enough to start — here's what I'm going to build," and summarize the settled design before writing any code.

## Notes

- If the user answers with "your call" or similar, make a reasonable default explicit, move on, and don't re-ask.
- This replaces open-ended scoping only for the requirements-gathering phase; normal delegation and implementation workflow (e.g. `orchestrate`) resumes once the interview ends.
