---
name: voice
description: Enforce natural, human writing style on text presented as the user: git commits, PR titles and descriptions, code comments, inline review replies, Slack messages, Slite docs, and any other human-facing content written in the user's voice. Trigger when the user asks to "check my voice", "fix the tone", "make this sound like me", or "apply voice rules". Also apply passively whenever drafting text the user will present as their own. Claude's own conversational replies are covered by `claude-response`, not this skill.
---

# Voice and Language Rules

These rules apply to every piece of text that will be shown, read, or attributed to the
user: git commit messages, PR titles and descriptions, code comments, inline review
replies, Slack messages, Slite docs, and any other human-facing content.

Claude's own responses in a terminal session are out of scope. Those follow
`~/.claude/skills/claude-response/SKILL.md` and the always-on block in
`~/.claude/CLAUDE.md`.

## Hard Rules (never do these)

- No em dashes (—). Use a comma, a colon, a period, or restructure the sentence.
- No en dashes used as em dashes (–). Same rule.
- No "delve", "delve into", or "dive deep".
- No "leverage" when "use" works.
- No "robust", "seamless", "cutting-edge", "comprehensive", or "innovative".
- No "ensure" when "make sure" fits better naturally.
- No "It's worth noting that" or "It's important to note that".
- No filler transitions like "Moving on to...", "Now let's look at...".
- No over-hedging: avoid "might potentially", "could possibly", "it seems like it may".
- No passive voice when active is cleaner.
- No inflated symbolism. Don't treat ordinary things as deeply meaningful ("this
  represents a fundamental shift in how we approach...").
- No promotional language: "powerful", "game-changing", "best-in-class", "next-level",
  "world-class".
- No superficial -ing analyses: avoid "By implementing X, we achieve Y" slide-deck
  framing.
- No vague attributions: "some say", "many believe", "experts suggest". Name the source
  or cut it.
- No rule of three. AI habitually groups things in threes to sound balanced. If two
  examples cover it, stop at two.
- No negative parallelisms: avoid "not only X but also Y" constructions.
- Also banned, all the standard AI tells: "utilize", "in order to", "allows you to",
  "a number of", "I'd be happy to", "Certainly!", "Absolutely!", "Of course!",
  "Great question!", "In conclusion", "To summarize", "In summary", "TL;DR", and
  "Furthermore" / "Moreover" / "Additionally" as sentence openers.

## Clarity

From the Google developer documentation style guide. These are about making a sentence
land, and they apply to every channel unless the carve-out that follows says otherwise.

- **Lead with the point.** Put the critical information in the first sentence of the
  message and the first sentence of each paragraph. Don't build up to it. Confirmed
  independently by `voice-audit` as `cut-preamble`, promoted 2026-08-20 on 3/3 pairs.
- **Be precise about required vs optional.** "must" or a bare imperative for required,
  "can" for optional, "might" for possible, "I recommend" for advice. Avoid "should";
  it blurs all four.
- **Only claim what you verified.** No superlatives (best, simplest, cleanest,
  fastest). Care with "ensure" and "guarantee". Say what was tested and what wasn't.
- **Give "this" and "these" a noun.** "This flag means...", not "This means...". A
  bare demonstrative makes the reader hunt for the antecedent.
- **No metaphors or figurative language.** Google names the failure mode exactly:
  reaching for a friendly tone is how figurative language gets in. Describe the thing.
- **No ableist or violent idiom.** Not "sanity check", "crazy", "cripples", "hangs",
  "dummy variable", "hit New". Use "final check", "unexpected", "slows", "doesn't
  respond", "placeholder", "click New".
- **Define a term on first use, then use it.** Spell out an acronym the first time.
  For jargon, either write around it or give it a short parenthetical. Non-technical
  terms too.
- **Keep the connective words:** "that", "then", "and then". Conversational English
  drops them and it costs clarity. "Start the profiler, and then run the app."
- **Say "earlier" and "following", not "above" and "below".** Position moves depending
  on where it's read.
- **Present tense, active voice, condition before instruction.** "To delete the
  document, click Delete", not "Click Delete if you want to delete the document".
- **Avoid double negatives.** "You can continue without a path", not "A missing path
  won't prevent you from continuing".
- **Introduce a list with a complete sentence,** not a fragment the items finish.
- **Qualify code names with a noun.** "the `example.yaml` file", "send a POST request".
  Not "POST the data".
- **Link text must stand alone.** "For more information about X, see Y." Never "click
  here". Use "see", not "refer to".

## Conversational channels

Slack, inline review replies, and anything else addressed to a person rather than to a
reader of documentation. The clarity rules above still hold. These exceptions override
them, because the doc-formality versions read as cold from a human.

- **"we" and "our" are correct.** You're on a team. The doc-style ban on first-person
  plural does not apply.
- **Validation and warmth are genuine.** "good catch", "nice find", "no worries",
  "no rush", "happy to help", "my bad". Keep them. They are not AI filler.
- **"please" is politeness,** not instruction filler. Fine when asking a person for
  something.
- **An exclamation mark is fine** in a greeting or a thanks. One, not three. Logged as
  your own pattern in `voice-audit` (`exclamation-greeting`).
- **Lowercase casual openers are yours.** Don't formalize them.
- **Emoji are fine in Slack** where you'd normally use them.

## Tone Goals

- Write like a competent engineer talking to a teammate. Direct, clear, not formal.
- Short sentences over long ones. One idea per sentence.
- Use contractions naturally (don't, it's, we're, can't). Especially negation
  contractions: a standalone "not" is easy to miss when scanning.
- When in doubt, cut the word. Less is better. But not at the cost of the connective
  words above.
- Single hedges like "maybe", "I think", "likely", "might" are natural and fine. The
  hard rule on over-hedging targets compound hedges like "might possibly", not these.
- Own mistakes plainly: "my bad", "I missed that", "sorry about that". Not corporate
  framing like "apologies for the confusion" or "I appreciate your patience".
- If a sentence fights back, ask "what am I trying to say?" and write that instead.
- Read it as though spoken. If it's awkward aloud, recast it.

## Commit Message Rules

- Imperative mood: "fix bug" not "fixed bug" or "fixes bug".
- No period at the end of the subject line.
- Subject line under 72 characters.
- No corporate speak or AI filler in the body.
- If a body is needed, explain *why*, not just *what* the diff already shows.

## PR Description Rules

- Lead with what changed and why in plain terms.
- No buzzwords.
- Bullet points are fine, but don't pad them.
- Test plan should describe what was actually tested, not generic steps.
- State what you did not test. An unqualified "tested" is a claim you can't back.

## Code Comment Rules

- Only comment when the code itself doesn't explain the intent.
- No "This function does X" when the function name already says X.
- Comments should be lowercase and conversational unless they're JSDoc/docblock.

## Applying This Skill

When the user asks to review or rewrite text under this skill:

1. Read the text carefully.
2. Flag every violation with a short label (em dash, AI phrase, passive voice, buried
   lead, bare demonstrative, unverified claim).
3. Offer a rewritten version that fixes the issues.
4. Keep the meaning intact. Only fix style and tone.
5. Don't over-correct. If something sounds natural and human already, leave it alone.

## Related

- `claude-response` covers Claude's own replies, and shares the Clarity section above.
- `voice-audit` measures this skill against reality using draft/sent pairs. It proposes
  edits and never writes without approval. Run its review mode to see what's ready.
