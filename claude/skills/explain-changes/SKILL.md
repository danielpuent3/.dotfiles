---
name: explain-changes
description: walk through code changes as a PR review, diff by diff, pausing between sections; use when asked to "explain changes", "walk me through this", "review this like a PR", or similar phrasing
---

# explain-changes

Present code changes as a structured PR review walkthrough. Show each diff piece, explain the why and what, then pause for the user to continue, ask questions, or make improvements inline.

## Mode Detection

Determine the mode before starting:

- **PR URL or number provided** → **Review mode**: collect comments throughout, post them to the PR at the end
- **No target given, current branch has an open PR** → Ask: "Are you reviewing this for feedback to leave on the PR, or walking through your own work?"
- **No target given, no open PR on the current branch** → **Walkthrough mode**: apply inline improvements, commit at the end

To check for an open PR on the current branch: `gh pr view --json number,url,state 2>/dev/null`

## Walkthrough Mode

Used when explaining your own work — the goal is understanding and cleanup.

- Spot issues or improvements as you go and offer to apply them inline
- Apply and commit cleanups the user agrees to during the walkthrough
- Wrap up with a summary of all inline changes made and a prompt to commit if not already done

### Prompt Options (Walkthrough)

Every section must end with an `AskUserQuestion` with these options:
1. **Continue** (Recommended) — description of what comes next
2. **Question on this section** — something needs clarification
3. **Skill notes** — pause to capture an improvement for this skill
4. **Something else** — free text / other direction

## Review Mode

Used when reviewing someone else's PR — the goal is feedback.

- Never attribute feedback to the assistant — present findings as feedback for the user to send
- Do not apply changes directly — queue them as review comments instead
- Keep comments human and conversational, not robotic or formal
- Wrap up by showing all queued comments, letting the user edit them, then posting via `gh pr review`

### Prompt Options (Review)

Every section must end with an `AskUserQuestion` with these options:
1. **Continue** (Recommended) — description of what comes next
2. **Leave a comment** — queue a comment on this section
3. **Skill notes** — pause to capture an improvement for this skill
4. **Something else** — free text / other direction

### Review Checklist

Apply these checks to each section as you walk through it:

1. **Naming** — flag abbreviated or ambiguous names; prefer fully spelled-out clarity
2. **Structure** — flag excessive nesting; prefer guard clauses and early returns
3. **Dead code** — flag unused logic, imports, or stale paths
4. **Security** — check for injection, sensitive-data leakage, or missing auth guards
5. **Performance** — check for obviously inefficient patterns (N+1 queries, work inside hot loops, redundant network calls)
6. **Test coverage** — new behaviour should have matching tests

### Comment Style

- For bugs: include concrete impact and a proposed fix direction
- For style suggestions: mark as optional unless it's a clear correctness issue
- Keep tone human — avoid em dashes and overly formal phrasing
- **Always draft the comment for the user first.** When the user chooses to leave a comment, write the full suggested reply text (tied to the file/line), show it to them, and let them edit it before posting. Once approved, post it immediately via `gh api repos/{owner}/{repo}/pulls/{number}/reviews` — do not queue it for the end. The user approves comments one at a time as they come up.

## Format Rules

- **One diff per turn.** Each section presents exactly one diff hunk (or one tightly coupled pair, like a function and its single direct caller). Do not stack multiple diffs in the same response — the user needs to be able to point at "this one" without ambiguity when they have a question.
- **Explain first, then show the diff.** Lead with one or two sentences on what the change is for and why it exists. Then show the diff. The user reads the framing first so they know what to look for inside the hunk.
- Keep explanations focused on **why** the change exists and **what** it does — not a line-by-line read of the code
- Do not omit parts of a diff with `...` — always show the full block
- Always show the **full diff hunks** from `git diff` for each file, with `+`/`-` markers and surrounding context. Do not paraphrase, summarize, or rewrite the code into a cleaner snippet. The user reads diffs to spot incidental changes, formatting shifts, and removed lines — paraphrased "just the interesting bit" snippets hide all of that. Use fenced ```diff blocks.
- **Bite size**: a diff hunk that spans more than ~40 lines or touches more than one logical concern should be split across multiple turns, even when the file is the same. Walk the file in passes (constructor, then method A, then method B) rather than dumping the whole file.
- **Always emit the diff inline in your response text as a fenced ```diff block, not just via a Bash `git diff` tool call.** Tool output isn't equivalent — the user reads your response. If you run `git diff` to fetch the hunk, paste the result into a fenced block before moving on.
  - **This is the single most-violated rule in this skill.** The failure mode is subtle: you run `git diff`, read the output, write a genuinely good analysis of it, and never paste it. The section reads fine to you because the diff is in your context. The user sees commentary on code they were never shown.
  - Self-check before ending any section: does my response text contain a literal ```diff fence? If not, the section is incomplete. Go back and paste it.
  - A section with no fenced diff is not a section. Never let analysis substitute for the diff.

- **Diff base: use three-dot when the PR base has moved.** `git diff base..head` shows every difference between the two tips, so if the base branch has advanced (or a stacked parent has merged) it renders those upstream commits as phantom deletions in your PR. Use `git diff base...head`, which diffs from the merge base and shows only what this branch actually changed. Verify the file list matches the PR's own "Files changed" count before presenting.
- **Bundle trivial repeated diffs.** When a rename or comment update sweeps across many files with one-line changes (e.g. updating an old method name in docblocks across 5 files), don't give each file its own turn. Bundle them into one section with one fenced block per file under a single explanation. Save full-turn treatment for hunks that have actual logic worth discussing.

## Order of Presentation

Walk changes in logical reading order, not file-system order. The general shape, applicable to any language or stack:

1. Entry point (route, CLI command, event handler, public API, exported function)
2. Main logic (the primary change — business rules, algorithm, state transitions)
3. Supporting code called by the main logic (helpers, side effects, downstream services)
4. External integrations (third-party SDKs, network calls, DB access)
5. Contracts / interfaces / types
6. Adapters or platform-specific implementations
7. Tests
8. Tooling / config (build files, CI, env, lint config)

Adjust order based on what makes the narrative clearest for the specific change. Never skip a diff — anything that doesn't fit a layer above goes into a final **Misc** section at the end (e.g. unrelated cleanups, formatting, stray renames) so every change is accounted for.

### Laravel / PHP subset

When the repo is a Laravel app, the layers above typically map to:

1. Route (`routes/*.php`)
2. Controller / form request
3. Service / domain class
4. Gateway or external SDK wrapper
5. Supporting services (notifications, discounts, analytics, jobs, listeners)
6. Contracts / interfaces
7. Platform stubs / adapters (no-op or delegating implementations)
8. Feature / unit tests
9. Tooling (Makefile, composer scripts, CI, `.env.example`)

## Skill Notes Handling

When the user selects "Skill notes", ask them what they want to capture, then update this SKILL.md with the note before resuming the walkthrough.

## Wrap Up

**Walkthrough mode:**
- Summarize all inline changes made during the walkthrough
- Prompt to commit if not already done

**Review mode:**
- Comments are posted inline as the user approves them during the walkthrough, not batched at the end.
- Post each approved comment immediately as an **inline line-level comment** using `gh api repos/{owner}/{repo}/pulls/{number}/reviews` with a `comments` array — each entry needs `path`, `line`, `side: "RIGHT"`, and `body`. Look up exact line numbers from the actual files (`grep -n`) before posting.
- **Never use `gh pr review --comment --body "..."` for review findings** — that posts a single block comment on the PR timeline, not inline on the code. Use the reviews API with the `comments` array instead.
