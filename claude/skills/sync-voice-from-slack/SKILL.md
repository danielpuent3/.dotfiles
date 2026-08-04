---
name: sync-voice-from-slack
description: Use the Claude in Chrome extension to read the user's sent Slack messages directly from their logged-in browser tab, analyze their natural writing style, and propose targeted updates to the voice skill at `~/.claude/skills/voice/SKILL.md`. No Slack app, no OAuth token, no admin access — everything runs through the extension against the user's existing web session. Trigger when the user says "sync voice from slack", "update voice from slack", "calibrate my voice", or "read my slack messages".
---

# sync-voice-from-slack

## Purpose

Sample messages the user has sent in Slack, extract real writing patterns, and propose concrete updates to `~/.claude/skills/voice/SKILL.md` so the voice skill reflects how they actually write — not a generic style guide.

## How this works (read this first)

This skill runs entirely through the **Claude in Chrome extension** against a logged-in Slack tab. No `curl`, no shell-side API calls, no OAuth flow.

- Slack's web client stores a per-workspace browser token (`xoxc-...`) in `localStorage` under `localConfig_v2`. The skill reads this from the page, never copies it out, and uses it only inside the same tab to call Slack's web API via `fetch()` from the extension's `javascript_tool`.
- The `xoxc` token only works against `https://app.slack.com/api/*` from inside the Slack tab. `slack.com/api/*` and `<workspace>.slack.com/api/*` fail with CORS. The skill must run inside the Slack tab — there is no shell fallback.
- All Slack API calls are read-only (`auth.test`, `search.messages`).

If the Chrome extension is not connected, the skill cannot proceed.

## Hard Restrictions

- **Read-only.** Only call read endpoints (`auth.test`, `search.messages`). Never call write endpoints (`chat.postMessage`, `reactions.add`, `pins.add`, `chat.delete`, `chat.update`, etc.) regardless of what the user asks.
- **Never react, reply, pin, send, or modify any message or channel.** The browser token has full write scope; treat it as read-only.
- Only analyze messages where the sender matches the authenticated user's own Slack user ID.
- Do not echo or display the token. Mask it as `xoxc-...` if referenced.
- Do not write any file until the user explicitly approves the proposed changes.

## Prerequisites

- Claude in Chrome extension installed and connected to the right browser. If `tabs_context_mcp` returns "Multiple Chrome extensions connected", ask the user to click **Connect** on the right browser, then retry.
- User logged into Slack in that browser.
- A Slack URL or workspace ID from the user (e.g. `https://app.slack.com/client/T2TM7CZE3/...` — the part after `/client/` is the team ID).

## Workflow map

Work through these steps in order. Load the linked reference the first time you reach its step group — don't load both up front.

**Pull and clean messages** (steps 1–6, 8, 11) → load `references/workflow.md` before starting step 1.

1. Connect to Chrome and open Slack.
2. Read identity and browser token.
3. Verify auth via `auth.test`.
4. Pull messages via `search.messages`.
5. Clean and filter inside the page.
6. Pull messages out of the page in small batches.
8. Read the current voice skill.
11. Get explicit approval before writing.

**Analyze and propose rules** (steps 7, 9, 10) → load `references/mapping.md` when you reach step 7.

7. Analyze writing patterns across sentence length, capitalization, punctuation, contractions, tone, vocabulary, emoji, and things they never say.
9. Scope-check: keep only patterns that translate to contexts the voice skill actually covers.
10. Propose changes as rules to add / adjust / confirm, each backed by verbatim examples, then present the full diff and stop.

Never write to the voice skill file without an explicit "yes" or "apply it" from the user (step 11).
