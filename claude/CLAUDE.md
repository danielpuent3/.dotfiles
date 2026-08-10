# VERY Important notes

## Git Commit Rules

- **Do NOT include `Co-Authored-By` trailers in commits for any project. This includes all variations (Co-Authored-By, Co-authored-by, etc.). Commits must only attribute the authenticated user.
- **Do NOT include "🤖 Generated with [Claude Code](https://claude.com/claude-code)" or any similar Claude/AI attribution lines in ANY output.** This applies everywhere: commit messages, PR titles, PR descriptions, issue bodies, code comments, docs, Slack messages, Slite docs, anything. No emoji robot lines, no "Generated with" footers, no "Made by AI" tags, no model names. The user's name is the only attribution.

## Environment Access

- **Never access staging or any non-local environment without explicit permission first.** This includes SSH into servers, running remote commands, deploying, or touching shared infrastructure. Ask for authorization before each such action — permission granted for one task does NOT carry over to the next. Local-only work needs no such permission.

## Code Style

- **Never align `=>` operators.** Use a single space before and after `=>`.
- **Do NOT over-comment.** Write code that explains itself; let names and structure carry the meaning. Don't narrate what the code obviously does (`// loop over items`, `// return failure`), don't restate the line below it, and don't add comments just to mark a change. Only add a comment when the *why* is genuinely non-obvious and can't be made clear by the code itself — and keep it to one short line. Default to no comment.

## Slite Writing

- **Every Slite doc is text published as the user.** Before any Slite write (`create-note`, `update-note`, `modify-block`, `modify-range`, `append-blocks`, `edit-document`, `update-table`), apply the `voice` rules and follow the `slite` skill at `~/.claude/skills/slite/SKILL.md`. No em dashes, no AI filler, direct engineer tone. This is not optional and not a find-and-replace pass; the prose must read coherently in the user's voice.

## Orchestration for substantial tasks

- **Substantial tasks (multi-step investigation, analysis, cross-repo work, or multi-file/logic changes): work in orchestration mode by following the `orchestrate` skill at `~/.claude/skills/orchestrate/SKILL.md`.** You plan, scope, reason, and synthesize directly. Delegate all real investigation and code changes to Sonnet subagents, and run independent ones in parallel. Trivial edits (one-liners, typos, tmp/memory writes) you do yourself. Skip this for quick questions and trivial asks.

## Todo system

- **Before assuming there's no tracked context for this session, check `~/.ai/todos/INDEX.md` for a bound todo.** See `~/.ai/todos/README.md` and `SPEC.md` for how the system works. Not every session has one — only check, don't require it.
