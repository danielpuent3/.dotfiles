---
name: slite
description: Read and write Streamlabs Slite docs correctly and in the user's voice. Use for ANY Slite work via the slite MCP tools (create-note, update-note, modify-block, modify-range, append-blocks, edit-document, update-table) — reading, authoring, or editing docs, especially the SLID API Reference. Loads and applies the voice rules before writing.
---

# Writing to Slite

Slite docs are human-facing content published under the Streamlabs org. Every doc you write or edit is text the user is presenting as their own. That means the `voice` skill applies to all of it, always.

## Before any Slite write: apply voice

Before calling any slite write tool (`create-note`, `update-note`, `modify-block`, `modify-range`, `append-blocks`, `edit-document`, `update-table`), the prose you're about to write must already follow the voice rules in `~/.claude/skills/voice/SKILL.md`. Read that file if it isn't already in context.

Quick reference for docs (the ones that bite most in Slite):

- No em dashes (—) and no en dashes used as em dashes (–). Use a comma, a period, or restructure. This is the single most common violation in these docs.
- The middle dot `·` in endpoint headers (`` `POST /path` · Auth: @authenticated ``) is NOT a dash. Keep it, it's the API Reference convention.
- No AI filler: "It's worth noting", "In summary", "Furthermore/Moreover/Additionally" as openers.
- No buzzwords: comprehensive, robust, seamless, powerful, cutting-edge, best-in-class.
- No rule of three. If two examples cover it, stop at two.
- Short sentences, one idea each. Contractions are fine. When in doubt, cut the word.
- Rewriting existing docs is not find-and-replace. Read the whole doc, fix the prose, and make sure it still reads coherently after the edit.

## sliteml gotchas (silent data loss if ignored)

- Do NOT include a `<document>` wrapper. Emit only block elements.
- Escape literal `<`, `>`, `&` in prose and table cells as `&lt;` / `&gt;` / `&amp;`. Do NOT escape inside fenced code blocks or `raw`/`json`/`code-block` blocks.
- In a `<database>`, every `<column>` needs a `key`, and every `<field columnKey="...">` must reference a real column `key` (not the column name). Record keys and block IDs are optional on new content, they're auto-generated.
- Preserve every `<comment id="...">` tag verbatim. Dropping one orphans a user's comment thread.
- Preserve `<note-link note-id="...">` cross-references. Syntax: `<note-link note-id="ID" title="Title">text</note-link>`.
- Bare `streamlabs.com` in prose auto-links. That's harmless; put it in a code block if you need it literal.

## Editing safely

- Call `get-note` (sliteml format) first to read block IDs. Partial edits target block IDs from the `{/* #id */}` markers or `id="..."` attributes.
- Prefer `modify-block` / `modify-range` on prose blocks. Leave `<database>` tables, code blocks, and their column keys untouched unless the content itself is wrong. This keeps technical data byte-stable while you fix prose.
- Use `update-note` (full-body replace) only when rebuilding a doc from scratch. It replaces the entire body, so carry over every table, code block, comment, and link.
- For structured table cell/row/column changes, use `update-table` rather than re-emitting the whole `<database>`.

## API Reference conventions

The SLID API Reference lives in Slite (parent doc `xGGato9KSkURyE`), not in the repo. It has one section doc per route group, plus a "Conventions & Shared Objects" doc.

- One H3 (`##` in these docs) per endpoint: title, then `` `METHOD /path` · Auth: <badge> ``, a short description, a Body/Query table, Responses, and an Errors table.
- Auth badges: `public`, `@authenticated`, `@client-authenticated`.
- Shared objects (Subscription, Plan, Payment Method, Transaction), `extends[]`, rate limits, and pagination live in "Conventions & Shared Objects". Reference them, don't repeat them.
- A new endpoint gets a new H3 in the right section; a new route group gets a new child doc under the API Reference.
- Keep the repo in sync: per this project's CLAUDE.md, endpoint changes in code must update the matching API Reference section in the same change.
