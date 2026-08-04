---
name: blind-spot-pass
description: Opt-in. Before implementing in an unfamiliar codebase or domain, hunt for unknown unknowns — assumptions, gaps, and things likely to differ from expectations — then surface the highest-impact ones to the user. Not default behavior; invoke only when the user asks, e.g. "blind spot pass", "what am I missing", "find unknown unknowns".
---

# blind-spot-pass

## Purpose

Catch the risks a normal implementation pass skips over: not "what does this code do" but "what am I assuming that might be wrong." Unfamiliar codebases and domains carry unknown unknowns that only surface once they break something.

## When to run this

Only when explicitly invoked. Good moments: right before implementing in a codebase or domain you haven't worked in, or when the user is about to commit to an approach and wants a sanity check first.

## Steps

### 1. Scope the unfamiliar territory

Name what's actually unfamiliar: a codebase, a library, a domain's business rules, an external API's behavior. Be specific — "the billing domain's proration rules," not "this codebase."

### 2. List your assumptions

Write down every assumption the planned approach depends on: about data shapes, invariants, who calls this code, what's already validated upstream, how errors propagate, what "normal" input looks like. Include assumptions so basic they'd normally go unstated.

### 3. Look for evidence against each assumption

For each assumption, spend a little effort trying to falsify it: grep for counterexamples, check edge cases in existing tests, read the one function that looks like it handles the weird case. Mark each assumption confirmed, contradicted, or unverified.

### 4. Flag gaps, not just wrong assumptions

Separate from assumptions: what does the task not say that it probably should? Missing error handling requirements, unstated concurrency expectations, undefined behavior for edge inputs.

### 5. Rank by impact

Sort findings by what would hurt most if wrong: silent data corruption and security issues first, then behavior changes visible to users, then internal-only surprises. Drop anything trivial.

### 6. Present the top items and ask

Show the user the ranked list — assumption or gap, why it matters, what confirming or denying it would change. Ask about the highest-impact ones before writing code. Don't ask about everything; only the ones where a wrong guess would be expensive to unwind.

## Notes

- This is a targeted pass, not a general code review. Skip style, naming, and anything `simplify` or `security-review` already cover.
- If nothing rises to the level of "worth asking," say so plainly instead of manufacturing questions.
