# .dotfiles

Personal dotfiles for macOS setup.

## What's included

- `.zshrc` — Main shell config (oh-my-zsh, NVM lazy-loading, PATH)
- `.zshrc_personal` — Personal aliases, pure prompt, `fzf`, autosuggestions, syntax highlighting
- `.zshrc_streamlabs` — Work-specific aliases and functions
- `.tmux.conf` — tmux config with vim-style bindings and Nord theme
- `.vimrc` — Vim config with vim-plug, NERDTree, fzf, Nord theme
- `.hyper.js` — Hyper terminal config
- `RectangleConfig.json` — Rectangle window manager config
- `AppleScripts/` — Automation scripts for Hyper and PhpStorm
- `loupedeck/` — Loupedeck device config
- `claude/` — Claude Code config: `CLAUDE.md`, `statusline-command.sh` (Nord-themed status bar), `skills/`, `settings.local.json`
- `claude/todo-system/` — file-based todo system for Claude sessions: `todo-session` binds a session to a work item, `tmux-todo-status.sh` puts a wrong-branch alarm in tmux's status bar. See `claude/todo-system/README.md`. The tooling travels with this repo; the actual queue at `~/.ai/todos/` is machine-local and untracked.

## Setup

```bash
git clone https://github.com/danielpuent3/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup.sh
```

After setup, open tmux and press `prefix + I` to install tmux plugins.

## Daily catch-up command

Run this on either machine to sync dotfiles + update tooling:

```bash
~/.dotfiles/update.sh
```

Optional flags:

```bash
# skip brew update/upgrade
DOTFILES_SKIP_SYSTEM_UPDATES=1 ~/.dotfiles/update.sh

# do not auto-push local commits
DOTFILES_AUTO_PUSH=0 ~/.dotfiles/update.sh

# also update all global npm packages
DOTFILES_UPDATE_NPM_GLOBALS=1 ~/.dotfiles/update.sh
```

## Agent Instructions

If an AI agent (Codex/Claude) is editing this repo, follow:

- [AGENTS.md](/Users/danielpuente/.dotfiles/AGENTS.md)
