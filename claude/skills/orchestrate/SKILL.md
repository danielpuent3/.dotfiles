---
name: orchestrate
description: Plan-and-delegate workflow for substantial tasks — investigation, analysis, cross-repo work, or multi-file changes. Main agent plans, scopes, reasons, synthesizes; Sonnet subagents do all investigation and code edits. Use for non-trivial multi-step work; skip for quick questions and one-line edits.
---

# Orchestration workflow

Use this for substantial work: multi-step investigation, analysis, cross-repo
tasks, or multi-file/logic changes. Skip it for quick questions, trivial
single-file edits, and one-liners.

This trades speed and tokens for breadth and rigor. It pays off on genuinely
hard or wide tasks and is pure overhead on small ones. When unsure, start solo
and escalate once the task proves bigger than one context.

## Roles

You (main agent) own:
- Planning and orchestration.
- Scoping the problem and confirming it with the user.
- Reasoning-heavy analysis and synthesis.
- All communication with the user and the final deliverable.
- Trivial edits: one-liners, typos, tmp files, memory writes.

Sonnet subagents own:
- All code and repo investigation (search, reading, tracing).
- All real code and file changes (multi-file, logic, anything non-trivial).
Spawn them with model: sonnet.

Rule of thumb: if it's legwork, delegate it. If it's judgment, keep it.

But don't over-delegate. Delegation has overhead. Don't spawn a subagent for
something one grep or file read would answer. Delegate when the work is broad
(many files, several search angles), deep (tracing across a repo), or
parallelizable. If you'd finish it in a couple of tool calls yourself, just do
it.

## Workflow

1. Scope before solving. Establish the real problem from the raw evidence
   before touching any artifact. State it back in one clear problem statement
   and get confirmation. Scope-and-confirm when the problem is ambiguous or the
   stakes are real. Skip straight to work when scope is already obvious or the
   user gave it to you explicitly. It's a default, not a hard gate.
2. Correct the framing when the evidence contradicts how the problem was
   described. Say so plainly.
3. Plan the work as independent investigation and change tasks.
4. Delegate. Launch independent investigations in parallel (multiple Agent
   calls in one message). Investigation is eager, changes are gated: before
   dispatching subagents to edit code, have an approved plan. Don't fan out
   edits on an unconfirmed approach.
5. Ground claims in what subagents actually verified. Don't assert a mechanism
   or a number you haven't confirmed. When something doesn't reconcile, fix it
   and say so, don't defend it.
6. Re-scope when new facts land. Update the plan instead of plowing ahead.
7. Synthesize and deliver.

## Delegating well

- Briefs must be self-contained. Subagents don't see this conversation, your
  tmp files, or earlier findings. Every brief stands alone: restate the goal,
  the relevant facts, the exact paths, and what "done" looks like.
  Under-specified briefs are the top cause of bad delegated work.
- One concern per subagent. Parallelize independent ones.
- Resolve symlinks before searching (Grep/Glob don't follow them).
- Ask for structured findings with file:line evidence, and tell them to flag
  uncertainty. Tell read-only investigators not to change anything.
- Audit what comes back. Read findings critically, spot-check surprising claims
  against the real file before building on them. A subagent's output returns to
  you, not the user, so relay what matters, don't paste it.
- For parallel file changes that could conflict, give subagents worktree
  isolation.

## Deliverables

- Store inputs and working state in tmp files to reference across the session.
- Save durable, non-obvious context to memory.
- Run any user-facing text through the voice skill.
- Copy the deliverable to the clipboard when that's the handoff, and confirm
  deliverable type and destination before producing it.
