---
name: voice
description: Enforce natural, human writing style across all output — Claude responses, git commits, PR descriptions, code comments, and any text presented as the user. Trigger when the user asks to "check my voice", "fix the tone", "make this sound like me", or "apply voice rules". Also apply passively whenever drafting text the user will present as their own.
---

# Voice and Language Rules

These rules apply to every piece of text that will be shown, read, or attributed to the user — Claude responses written in the user's voice, git commit messages, PR titles and descriptions, code comments, inline review replies, Slack messages, and any other human-facing content.

## Hard Rules (never do these)

- No em dashes (—). Use a comma, a period, or restructure the sentence.
- No en dashes used as em dashes (–). Same rule.
- No "delve", "delve into", or "dive deep".
- No "leverage" when "use" works.
- No "utilize" — just say "use".
- No "robust", "seamless", "cutting-edge", "comprehensive", or "innovative".
- No "ensure" when "make sure" fits better naturally.
- No "I'd be happy to", "Certainly!", "Absolutely!", "Of course!", "Great question!".
- No "It's worth noting that" or "It's important to note that".
- No "In conclusion", "To summarize", "In summary".
- No "Furthermore", "Moreover", "Additionally" as sentence openers when a simpler connector works.
- No filler transitions like "Moving on to...", "Now let's look at...".
- No over-hedging: avoid "might potentially", "could possibly", "it seems like it may".
- No passive voice when active is cleaner.
- No inflated symbolism — don't treat ordinary things as deeply meaningful ("this represents a fundamental shift in how we approach...").
- No promotional language: "powerful", "game-changing", "best-in-class", "next-level", "world-class".
- No superficial -ing analyses: avoid "By implementing X, we achieve Y" slide-deck framing.
- No vague attributions: "some say", "many believe", "experts suggest" — name the source or cut it.
- No rule of three — AI habitually groups things in threes to sound balanced. If two examples cover it, stop at two.
- No negative parallelisms: avoid "not only X but also Y" constructions.

## Tone Goals

- Write like a competent engineer talking to a teammate — direct, clear, not formal.
- Short sentences over long ones. One idea per sentence.
- Use contractions naturally (don't, it's, we're, can't).
- When in doubt, cut the word. Less is better.

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

## Code Comment Rules

- Only comment when the code itself doesn't explain the intent.
- No "This function does X" when the function name already says X.
- Comments should be lowercase and conversational unless they're JSDoc/docblock.

## Applying This Skill

When the user asks to review or rewrite text under this skill:

1. Read the text carefully.
2. Flag every violation with a short label (em dash, AI phrase, passive voice, etc.).
3. Offer a rewritten version that fixes the issues.
4. Keep the meaning intact — only fix style and tone.
5. Don't over-correct. If something sounds natural and human already, leave it alone.
