---
name: pre-merge-quiz
description: Opt-in. Before merging, quiz the user on the change — what it does, why, edge cases, blast radius — and recommend merging only after they answer correctly. Not default behavior; invoke only when the user asks, e.g. "quiz me on this", "pre-merge quiz", "quiz me before merge".
---

# pre-merge-quiz

## Purpose

A comprehension check before merge. If the user can't answer what their own change does and why, that's a signal to slow down before shipping it — especially for changes the user didn't write line-by-line themselves.

## When to run this

Only when explicitly invoked, right before a merge or PR approval.

## Steps

### 1. Review the actual diff

Read the real changes (not just the PR description) to ground the questions in what the code does, not what it claims to do.

### 2. Ask one question at a time, across these categories

- **What**: What does this change actually do, concretely?
- **Why**: What problem does it solve, and why this approach over alternatives?
- **Edge cases**: What inputs or states could break this? What did the tests cover, and what didn't they?
- **Blast radius**: What else could this affect — other callers, data, downstream services, rollback difficulty?

Pick questions from the actual diff, not generic ones. If the diff touches a shared function, ask about its other callers. If it changes a schema, ask about migration safety.

### 3. Evaluate answers honestly

Don't accept a vague or wrong answer just to move things along. If an answer is wrong or missing, say so and explain the actual answer from the diff.

### 4. Give a recommendation

- If the user answers correctly across categories: recommend merging.
- If gaps show up: name them specifically and recommend addressing them (more tests, a follow-up doc, a second look at blast radius) before merge. The decision to merge anyway stays with the user — this is a check, not a gate.

## Notes

- Keep it to a handful of sharp questions, not an exhaustive checklist.
- This complements `ready-for-review` and `pr-review`, it doesn't replace their mechanical checks (tests, changelog, lint).
