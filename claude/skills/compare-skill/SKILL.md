---
name: compare-skill
description: Compare a proposed skill against existing skills in ~/.claude/skills/. Analyzes overlap, identifies useful additions, flags fluff or harmful instructions, and recommends concrete changes. Use when the user pastes a skill description or content and wants an honest analysis before adopting it.
---

# compare-skill

## Purpose

Given a proposed skill (pasted content, a description, or a file path), compare it against the existing skill library and give an honest, unbiased recommendation on what to adopt, adapt, or discard.

## Steps

### 1. Read the proposed skill

Accept the skill as whatever the user provides: raw text, a description, a file path, or a URL. If it's a file path, read it. If it's a description or pasted content, treat it as-is.

### 2. Determine the skill scope

Check the current working directory to decide which skills to compare against. Do not mix scopes.

- If the cwd is `~/.claude` or there is no local skill directory, read from `~/.claude/skills/` (global).
- Otherwise, look for a local skill directory in this order:
  1. `.claude/skills/` relative to cwd
  2. `.agents/skills/` relative to cwd
- If a local skill directory exists, read only from there. Do not also read the global skills.
- If neither local path exists, fall back to `~/.claude/skills/` and note in the output that no local skills were found.

Read every SKILL.md found under the resolved directory before analysis — don't rely on memory of what skills exist.

### 3. Read the relevant CLAUDE.md and AGENTS.md

These files define project-level rules that skills must not conflict with. Read them from the same scope as the skills:

- If using global scope: read `~/.claude/CLAUDE.md` if it exists.
- If using local scope: look for and read (in order, if present):
  1. `CLAUDE.md` in cwd
  2. `AGENTS.md` in cwd
  3. `.claude/CLAUDE.md` in cwd
- If a file doesn't exist, skip it silently — don't error.

Use these files to catch conflicts between the proposed skill and established project or global rules. A proposed skill that contradicts a CLAUDE.md rule is a conflict, even if no existing skill covers the same ground.

### 4. Analyze the proposed skill

Evaluate it across four dimensions:

**Coverage overlap**
- Which existing skills already handle what this skill proposes?
- Is the overlap partial or complete?
- Would adopting this skill create conflicting instructions?

**Useful parts**
- What does this skill do that nothing in the existing library covers?
- What instructions are specific, actionable, and genuinely improve output?
- What patterns or rules would be hard to derive on the fly without explicit guidance?

**Fluff / non-useful parts**
- Vague instructions with no clear behavioral effect ("be thoughtful", "consider context")
- Rules that restate obvious defaults Claude already follows
- Padding that adds length without adding guidance
- Marketing language in the skill itself ("comprehensive", "powerful")
- Steps that describe what the user will do rather than what Claude should do

**Harmful or risky parts**
- Instructions that conflict with existing skills and would cause inconsistent behavior
- Rules that would degrade output quality or strip useful behavior
- Overly broad restrictions that might suppress correct responses
- Anything that contradicts established rules (e.g., the voice skill's hard bans)

### 5. Give a verdict

Be direct. For each section, give a clear verdict:

- **Adopt as-is**: this part is useful and not already covered — add it
- **Adapt**: this part has a good idea but needs to be rewritten to fit the existing library
- **Merge**: this part belongs in an existing skill rather than a new one
- **Discard**: this part is fluff, harmful, or redundant

### 6. Recommend concrete changes

After the analysis, give a specific action list:

- If something should be added to an existing skill, name the skill and quote the proposed addition.
- If a new skill is warranted, say so and explain why it earns its own file.
- If nothing should change, say that plainly and explain why the proposed skill doesn't clear the bar.

Do not recommend changes just to appear thorough. If the proposed skill adds nothing, say so.

## Output Format

```
## Proposed Skill: [name or summary]

### Overlap with existing skills
[list any existing skills that already cover this ground]

### Useful parts
[bullet list — be specific, quote the relevant lines]

### Fluff / non-useful parts
[bullet list — explain why each item doesn't pull its weight]

### Harmful or conflicting parts
[bullet list — explain the risk or conflict]

### Verdict
[Adopt / Adapt / Merge / Discard — one line per section analyzed]

### Recommended changes
[concrete action list]
```

## Principles

- Be honest. A skill that adds nothing should be told it adds nothing.
- Quote the proposed skill directly when flagging issues — don't paraphrase.
- Don't recommend adding things just because they sound reasonable. Only recommend what demonstrably improves on what already exists.
- Keep the analysis focused on behavioral impact. The question is always: does this change what Claude does, and is that change an improvement?
