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

## Steps

All `js` blocks below execute via the Chrome extension's `javascript_tool` against the Slack tab. Replace `<TEAM_ID>` and `<USERNAME>` with values from steps 2 and 3.

### 1. Connect to Chrome and open Slack

```
tabs_context_mcp(createIfEmpty: true)
navigate(url: "https://app.slack.com/client/<TEAM_ID>/<ANY_CHANNEL>", tabId)
```

Any Slack URL the user provided is fine; the team ID is the part that matters.

### 2. Read identity and browser token

```js
(() => {
  const config = JSON.parse(localStorage.getItem('localConfig_v2'));
  const team = config.teams['<TEAM_ID>'];
  return JSON.stringify({
    user_id: team.user_id,
    team_name: team.name,
    has_token: !!team.token
  });
})()
```

Save `user_id`. Do NOT echo `team.token`. The token is read inline inside each subsequent snippet — never copied out of the page.

### 3. Verify auth

```js
(async () => {
  const token = JSON.parse(localStorage.getItem('localConfig_v2')).teams['<TEAM_ID>'].token;
  const fd = new FormData();
  fd.append('token', token);
  const res = await fetch('https://app.slack.com/api/auth.test', { method:'POST', body:fd, credentials:'include' });
  const data = await res.json();
  return JSON.stringify({ok: data.ok, user: data.user, error: data.error});
})()
```

Save `data.user` (e.g. `dpuente`) — used as `from:@<USERNAME>` in the search query. If `ok` is false, stop.

### 4. Pull messages via search.messages

`search.messages` returns the user's own messages across every channel and DM in one call. Far more efficient than walking each channel's history.

```js
(async () => {
  const token = JSON.parse(localStorage.getItem('localConfig_v2')).teams['<TEAM_ID>'].token;
  const all = [];
  for (let page = 1; page <= 5; page++) {
    const fd = new FormData();
    fd.append('token', token);
    fd.append('query', 'from:@<USERNAME>');
    fd.append('count', '100');
    fd.append('sort', 'timestamp');
    fd.append('sort_dir', 'desc');
    fd.append('page', String(page));
    const res = await fetch('https://app.slack.com/api/search.messages', { method:'POST', body:fd, credentials:'include' });
    const data = await res.json();
    if (!data.ok) return 'err on page '+page+': '+data.error;
    for (const m of (data.messages?.matches || [])) {
      all.push({
        text: m.text,
        ch: m.channel?.name,
        is_dm: !!m.channel?.is_im,
        is_mpim: !!m.channel?.is_mpim,
        ts: m.ts
      });
    }
  }
  window.__msgs = all;
  return JSON.stringify({count: all.length});
})()
```

Aim for 500+ messages. Pages 1–5 cover a week or two for active users. For more historical variety, also pull a few non-contiguous pages (e.g. 20, 50, 100) and check timestamps to confirm different time periods.

### 5. Clean and filter inside the page

Strip Slack syntax so analysis sees real prose, then drop link dumps and log spam:

```js
(() => {
  window.__cleaned = window.__msgs.map(m => {
    let t = m.text || '';
    t = t.replace(/<(https?:\/\/[^|>]+)\|([^>]+)>/g, '$2');     // <url|label> → label
    t = t.replace(/<https?:\/\/[^>]+>/g, '[LINK]');              // <url> → [LINK]
    t = t.replace(/https?:\/\/\S+/g, '[LINK]');                  // bare urls
    t = t.replace(/<@U[A-Z0-9]+>/g, '@user');                    // <@UXXX> → @user
    t = t.replace(/<#C[A-Z0-9]+\|([^>]+)>/g, '#$1');             // <#CXXX|name> → #name
    t = t.replace(/[\w.-]+@[\w.-]+\.\w+/g, '[EMAIL]');           // emails
    // <!here>, <!channel> are kept as-is — broadcast usage is signal
    return { text: t, ch: m.ch, is_dm: m.is_dm, is_mpim: m.is_mpim };
  });
  window.__filtered = window.__cleaned.filter(m => {
    const t = (m.text || '').trim();
    if (!t) return false;
    const noLinks = t.replace(/\[LINK\]/g, '').replace(/[-\s]+/g,'').trim();
    if (noLinks.length < 3) return false;                        // pure link dumps
    if (t.length > 500 && (t.match(/\n/g) || []).length > 10) return false; // logs/stacktraces
    if (!/[a-zA-Z]{2,}/.test(t)) return false;
    return true;
  });
  return JSON.stringify({before: window.__cleaned.length, after: window.__filtered.length});
})()
```

### 6. Pull messages out of the page in small batches

The Chrome extension's `javascript_tool` will block responses that look like cookie or query-string data with `[BLOCKED: Cookie/query string data]`. The trigger is opaque and inconsistent. Workarounds:

- Pull slices of 10–25 at a time.
- If a slice is blocked, retry with a smaller slice (5–10) or a different range.
- Truncate per-message text to 150–250 chars; you don't need full long messages to spot patterns.

```js
window.__filtered.slice(0, 20).map(m => m.text.slice(0,200)).join('\n|||\n')
```

For bulk numbers, run the analysis inside the page and only return the stats:

```js
(() => {
  const m = window.__filtered.map(x => x.text);
  return JSON.stringify({
    total: m.length,
    avg_length: Math.round(m.reduce((s,t)=>s+t.length,0) / m.length),
    starts_lowercase: m.filter(t=>/^[a-z]/.test(t.trim())).length,
    starts_uppercase: m.filter(t=>/^[A-Z]/.test(t.trim())).length,
    ends_period: m.filter(t=>/\.$/.test(t.trim())).length,
    ends_no_punct: m.filter(t=>/[a-zA-Z0-9)\]]$/.test(t.trim())).length,
    ends_question: m.filter(t=>/\?$/.test(t.trim())).length,
    ends_exclaim: m.filter(t=>/!$/.test(t.trim())).length,
    uses_em_dash: m.filter(t=>/—/.test(t)).length
    // add more counters based on what the current voice skill cares about
  });
})()
```

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

### 8. Read the current voice skill

```
Read('~/.claude/skills/voice/SKILL.md')
```

If outside connected folders, request access via `request_cowork_directory`.

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

### 11. Get explicit approval

Ask: "Apply these changes to the voice skill?"

- If yes: edit `~/.claude/skills/voice/SKILL.md` with only the approved changes, then report what changed.
- If revise: discuss the specific points and re-present the diff.
- If no: do nothing.

Never write to the voice skill file without an explicit "yes" or "apply it".

## Notes and gotchas

- **CORS:** `xoxc` only works against `https://app.slack.com/api/*` from inside the Slack tab. Other origins fail with "Failed to fetch". This is why the skill must run inside the Slack tab via the Chrome extension — there is no shell fallback.
- **Pagination:** `search.messages` paginates 100 per page. Active users have tens of thousands; you don't need them all. 500–1000 is plenty.
- **Bot/automated content:** Messages where `user == <USER_ID>` can still be automated (deploy bot pastes, copy-pasted PR links). The link-dump and stacktrace filters in step 5 catch most.
- **Context-specific noise:** Ask "does this pattern appear across multiple distinct threads, or is one conversation flooding the sample?" Pull stats but verify by reading actual messages.
- **Chrome extension blocking:** `[BLOCKED: Cookie/query string data]` is opaque and inconsistent. Pull in small batches; retry on block; do bulk analysis inside the page.
- **Token safety:** The `xoxc` token grants full write access to the workspace as the user. Treat it like a password. Never echo, log, or persist it outside the browser.
