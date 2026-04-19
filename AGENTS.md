# AGENTS.md

Instructions for coding agents (Codex and Claude) working in this repository.

## Purpose

This repo manages macOS developer environment state across two machines. Recent work (last 20 commits) centers on:

- Keeping `setup.sh` and `update.sh` as the source of truth for install/update flows
- Managing shell + tmux + vim + Hyper config together
- Supporting dark/light theme switching via `.theme` and `scripts/theme-toggle.sh`
- Tracking Claude config/skills inside dotfiles

Agents should preserve this model and avoid one-off local-only fixes.

## Core Workflow

1. Prefer editing tracked dotfiles and scripts over manual instructions.
2. After edits, run the relevant reload/install commands automatically (see matrix below).
3. Validate shell scripts/config syntax before finishing.
4. If dependencies are required (for example `fd`, `fzf`), add them to both `setup.sh` and `update.sh` required package list.
5. Keep `README.md` in sync for user-facing commands/flags.

## Required Post-Change Commands

Run these automatically after making related changes:

- If `.zshrc`, `.zshrc_personal`, or `.zshrc_streamlabs` changed:
  - `zsh -n ~/.dotfiles/.zshrc ~/.dotfiles/.zshrc_personal ~/.dotfiles/.zshrc_streamlabs`
  - `zsh -lc 'source ~/.zshrc'`

- If `.tmux.conf` or `tmux/*.tmuxtheme` changed:
  - `tmux source-file ~/.tmux.conf` (when tmux server/session is running)
  - If needed: `tmux refresh-client -S`

- If `.vimrc` or `vim/colors/*.vim` changed:
  - `vim +PlugInstall +qall`

- If `setup.sh`, `update.sh`, or `scripts/*.sh` changed:
  - `chmod +x ~/.dotfiles/setup.sh ~/.dotfiles/update.sh`
  - `find ~/.dotfiles/scripts -type f -name '*.sh' -exec chmod +x {} \;`
  - `zsh -n ~/.dotfiles/setup.sh ~/.dotfiles/update.sh`

- If fzf integration/config changed:
  - `FZF_PREFIX="$(brew --prefix fzf 2>/dev/null || true)"; [ -x "$FZF_PREFIX/install" ] && "$FZF_PREFIX/install" --all --no-bash --no-fish || true`

## Known Gotchas

- **tmux "open terminal failed: not a terminal" after `brew upgrade`** — the old tmux server process stays in memory while the new binary replaces it on disk, causing a client/server mismatch. Fix: `tmux kill-server`, then reopen the terminal. This is not a config issue.
- **Global npm CLIs (e.g. `codex`) not found** — NVM is lazy-loaded and only initializes on `nvm`, `node`, `npm`, `npx`, or `codex`. If you install a new global npm CLI that needs to be available at the prompt, add a lazy-loader wrapper for it in `.zshrc` alongside the existing ones.
- **`claude/statusline-command.sh` must be executable** — if the Claude Code status line stops rendering, check that `chmod +x ~/.dotfiles/claude/statusline-command.sh` has been applied.

## Repository-Specific Guardrails

- Do not edit or move Kiro-managed pre/post blocks in `.zshrc`.
- Keep theme behavior centralized through:
  - `~/.dotfiles/.theme`
  - `scripts/theme-toggle.sh`
  - tmux theme overrides in `.tmux.conf`
- Keep symlink behavior centralized in `setup.sh` and `update.sh`; do not introduce parallel sync scripts.
- Do not add `Co-Authored-By` trailers in commit messages.
- Do not align `=>` operators with extra spacing.

## Preferred Maintenance Command

Use this as the standard catch-up operation on either machine:

- `~/.dotfiles/update.sh`

If a change introduces new required tools, ensure `update.sh` can install missing packages (not only upgrade existing ones).
