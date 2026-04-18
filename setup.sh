#!/bin/bash

set -e

echo "==> Setting up dotfiles..."

# install homebrew
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "==> Homebrew already installed"
fi

# install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "==> oh-my-zsh already installed"
fi

# brew packages
echo "==> Installing brew packages..."
brew install --cask hyper 2>/dev/null || true
brew install gh 2>/dev/null || true
brew install zsh 2>/dev/null || true
brew install tmux 2>/dev/null || true
brew install pure 2>/dev/null || true
brew install fzf 2>/dev/null || true
brew install zsh-autosuggestions 2>/dev/null || true
brew install zsh-syntax-highlighting 2>/dev/null || true
brew install universal-ctags 2>/dev/null || true
brew install ripgrep 2>/dev/null || true
brew install fd 2>/dev/null || true

# fzf shell integration (zsh key bindings + completion)
FZF_PREFIX="$(brew --prefix fzf 2>/dev/null || true)"
if [ -n "$FZF_PREFIX" ] && [ -x "$FZF_PREFIX/install" ]; then
  "$FZF_PREFIX/install" --all --no-bash --no-fish || true
fi

# install NVM
if [ ! -d "$HOME/.nvm" ]; then
  echo "==> Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
  echo "==> NVM already installed"
fi

echo "==> Installing Node.js LTS and Codex CLI..."
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
fi
npm install -g @openai/codex

# install TPM (tmux plugin manager)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo "==> TPM already installed"
fi

# symlink dotfiles
echo "==> Creating symlinks..."
ln -sf ~/.dotfiles/.zshrc ~/.zshrc
ln -sf ~/.dotfiles/.tmux.conf ~/.tmux.conf
ln -sf ~/.dotfiles/.vimrc ~/.vimrc
ln -sf ~/.dotfiles/.hyper.js ~/.hyper.js
mkdir -p ~/.claude
ln -sf ~/.dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/.dotfiles/claude/settings.local.json ~/.claude/settings.local.json
ln -sf ~/.dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh
rm -rf ~/.claude/skills
ln -sf ~/.dotfiles/claude/skills ~/.claude/skills

echo "==> Done! Restart your terminal or run: source ~/.zshrc"
