# CLAUDE.md

This repo manages a macOS developer environment across two machines. Read `AGENTS.md` before making any changes — it is the source of truth for how to work here.

## Critical guardrails (see AGENTS.md for full detail)

- Run the post-change commands listed in AGENTS.md after editing shell, tmux, vim, or script files.
- Keep `setup.sh` and `update.sh` as the single source of truth for install/sync flows.
- Keep theme behavior centralized through `.theme` and `scripts/theme-toggle.sh`.
- If you add a new global npm CLI tool, add a lazy-loader wrapper for it in `.zshrc` alongside `nvm`, `node`, `npm`, `npx`, `codex`.
- Do not edit the Kiro-managed pre/post blocks in `.zshrc`.
- Do not add `Co-Authored-By` trailers in commit messages.
- Do not align `=>` operators with extra spacing.
