# Workflow: pulling and cleaning messages

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

### 8. Read the current voice skill

```
Read('~/.claude/skills/voice/SKILL.md')
```

If outside connected folders, request access via `request_cowork_directory`.

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
