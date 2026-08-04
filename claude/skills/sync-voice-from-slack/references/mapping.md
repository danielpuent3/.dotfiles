# Mapping: analyzing patterns and proposing voice rules

### 7. Analyze writing patterns

Read the messages and stats. Identify patterns across these dimensions:

**Sentence and message length**
- Typical message length: very short (1–5 words), short (1 sentence), medium (2–3 sentences), long (4+).
- Do they send fragmented multi-message bursts or complete single messages?

**Capitalization**
- Do they capitalize sentence starts consistently?
- All-lowercase messages: rare, occasional, or frequent?
- How do they capitalize proper nouns, product names?

**Punctuation habits**
- Do they end short messages with periods or leave them off?
- Use of commas: sparse or frequent?
- Ellipses (`...`): never, occasionally, often?
- Question marks at end of requests vs. statements?

**Contractions**
- Which do they use naturally? (don't, can't, it's, we're, I'll, etc.)
- Do they ever write out "do not", "cannot" instead?

**Tone and directness**
- Direct statements vs. hedged ("might", "maybe", "I think")?
- How do they push back or disagree?
- How do they ask for things: request, directive, question?

**Vocabulary**
- Recurring words and phrases unique to them.
- Technical shorthand they use naturally.
- Words they conspicuously avoid.

**Emoji and broadcasts**
- Which emoji, how often, sentence punctuation vs. standalone?
- Do they use `<!here>` or `<!channel>` (kept as-is in step 5 for this reason)?

**Things they never say**
- AI phrases, corporate buzzwords, filler words — note their absence.

Guardrails:
- Only the authenticated user's messages count.
- Watch for context-specific artifacts: a single thread can flood the sample with words that aren't general patterns (testing-loop confirmations, deploy bot pastes, single-topic threads). When a word shows up dozens of times, sanity-check that it spans multiple distinct conversations before treating it as a voice pattern.
- If you can't tell whether a pattern is general or context-specific, ask the user.

### 9. Scope-check before proposing rules

The voice skill governs specific output contexts (Claude responses, commits, PRs, code comments). Slack-specific habits (lowercase starts, dropped periods, casual emoji, `cc @user`) only belong in the voice skill if the user actually has Claude write for them in Slack. Otherwise those patterns are useful for **calibrating analysis** but not for **adding rules**.

Filter your proposed additions to patterns that translate to the contexts the skill actually covers.

### 10. Propose changes

For each proposed change:

- 1–2 verbatim short examples from the user's messages as evidence.
- The pattern the rule captures.
- The exact line(s) to add or modify.

Organize into:

**Rules to add** — patterns present in the data but not covered by the current skill.

**Rules to adjust** — current rules that conflict with observed behavior (e.g., the skill says "no ellipses" but the user uses them regularly).

**Rules confirmed accurate** — existing rules the data supports; brief list so the user knows what was validated.

Only propose rules backed by clear, multi-conversation evidence. No single-occurrence rules.

When drafting new bullets, follow the voice skill's own rules (no em dashes, no AI filler, etc.) — including in the rules you add.

Present the full proposed diff in a readable format before asking for approval. Do not write yet.
