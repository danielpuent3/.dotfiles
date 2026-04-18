#!/bin/bash
set -e

DOTFILES="$HOME/.dotfiles"

echo "==> Pulling latest changes..."
git -C "$DOTFILES" pull

echo "==> Refreshing symlinks..."
ln -sf "$DOTFILES/.zshrc"    ~/.zshrc
ln -sf "$DOTFILES/.tmux.conf" ~/.tmux.conf
ln -sf "$DOTFILES/.vimrc"    ~/.vimrc
ln -sf "$DOTFILES/.hyper.js" ~/.hyper.js
mkdir -p ~/.claude
ln -sf "$DOTFILES/claude/CLAUDE.md"              ~/.claude/CLAUDE.md
ln -sf "$DOTFILES/claude/settings.local.json"    ~/.claude/settings.local.json
ln -sf "$DOTFILES/claude/statusline-command.sh"  ~/.claude/statusline-command.sh
rm -rf ~/.claude/skills
ln -sf "$DOTFILES/claude/skills" ~/.claude/skills

echo "==> Ensuring scripts are executable..."
chmod +x "$DOTFILES/scripts/"*.sh

echo "==> Updating Codex CLI..."
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
fi
npm install -g @openai/codex

echo "==> Copying vim color schemes..."
mkdir -p ~/.vim/colors
cp "$DOTFILES"/vim/colors/*.vim ~/.vim/colors/ 2>/dev/null || true

echo "==> Installing vim plugins..."
vim +PlugInstall +qall 2>/dev/null || true

echo "==> Reloading tmux config..."
if [ -n "${TMUX:-}" ]; then
  tmux source-file ~/.tmux.conf
  echo "    tmux reloaded"
else
  echo "    (tmux not running, config will load on next session)"
fi

echo "==> Done!"
