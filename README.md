# .dotfiles

Personal dotfiles for macOS setup.

## What's included

- `.zshrc` — Main shell config (oh-my-zsh, NVM lazy-loading, PATH)
- `.zshrc_personal` — Personal aliases, pure prompt, syntax highlighting
- `.zshrc_streamlabs` — Work-specific aliases and functions
- `.tmux.conf` — tmux config with vim-style bindings and Nord theme
- `.vimrc` — Vim config with vim-plug, NERDTree, fzf, Nord theme
- `.hyper.js` — Hyper terminal config
- `RectangleConfig.json` — Rectangle window manager config
- `AppleScripts/` — Automation scripts for Hyper and PhpStorm
- `loupedeck/` — Loupedeck device config

## Setup

```bash
git clone https://github.com/danielpuent3/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup.sh
```

After setup, open tmux and press `prefix + I` to install tmux plugins.
