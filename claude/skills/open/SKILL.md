---
name: open
description: open a link the bound todo already holds in Safari, focusing an existing tab instead of stacking a duplicate. Trigger on /open, "/open pr", "open the doc", "open the asana task", "open the sentry issue", "what links does this todo have".
---

# open

Open something the current session already knows about, in Safari. If a tab is
already showing it, focus that tab rather than opening a second one.

There is no alias file to maintain. Every link the session can reach comes out of
one command, and you match what the user typed against that list.

## The two scripts

```bash
LINKS=~/.claude/skills/open/scripts/links.sh
OPEN=~/.claude/skills/open/scripts/open-or-focus.applescript
```

Always call them by absolute path — your cwd is wherever the session started.

`$LINKS` takes no arguments and prints `KEY|field|value` lines:

| Line | Meaning |
|---|---|
| `TODO\|<slug>` | the todo these links came from |
| `LINK\|<field>\|<url>` | a URL in that todo's frontmatter, tagged with the field holding it |
| `PR\|<branch>\|<url>` | the current branch's open PR, emitted only when the todo names no PR |
| `NOTE\|<text>` | why a source gave nothing |

`osascript "$OPEN" <url>` then prints `opened <url>` or `focused <url>`.

## You are the matcher

Score what the user typed against **both the field name and the whole URL**. That
covers everything without a lookup table:

| Typed | Matches on |
|---|---|
| `pr` | the `pr_urls` field |
| `asana`, `slite`, `sentry`, `google doc` | the host |
| `928`, `zevent`, `oracle` | anywhere in the URL |

## Hard rules

1. **Never invent a URL.** If it is not in `$LINKS` output, it is not openable. Say
   so instead of guessing at one.
2. **One match, open it.** Don't confirm first. That's the whole point of the skill.
3. **Several matches, list and ask.** Real todos carry two PRs or two Slite docs.
   Show them with enough of the URL to tell them apart, and let the user pick.
4. **Bare `/open` opens the obvious thing.** With no argument, in this order:
   exactly one `LINK|pr_urls|` line, open that PR; failing that, exactly one link of
   any kind, open that; failing that, rule 5. A `PR|` line from `gh` counts as the
   single PR, but say it came from the branch rather than the todo.
5. **Otherwise show the full list.** No match, or nothing unambiguous to open. Never
   a dead end. "I know I put the link in here" is the main reason this exists, so an
   empty query means *show me what I've got*, not an error.
6. **Report in one line.** `Focused the tab already open on PR #928.` The script tells
   you whether it opened or focused; pass that through, don't paraphrase it away.

## When the link isn't there

`$LINKS` reads frontmatter only, because that's the curated part. A URL pasted into
the body during an investigation won't show up.

So when the user asks for something that isn't in the list, and it exists, offer to
add it to the right frontmatter field so it's reachable next time. That's the loop
that keeps this useful.

## Behaviour worth knowing

- Matching a tab is exact first, then prefix. Asking for a PR while sitting on
  `/pull/928/files` focuses that tab instead of opening the bare PR again.
- Safari only. It is the registered `https` handler on this machine.
- Safari keeps closed windows in its enumeration as invisible, zero-tab objects, so
  new tabs go to the frontmost *visible* window. With no usable window at all, the
  script opens a new one.
