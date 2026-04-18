#!/bin/bash
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

if [ ! -d "$DOTFILES/.git" ]; then
  echo "[error] Dotfiles repo not found at $DOTFILES"
  exit 1
fi

log() {
  echo "==> $*"
}

warn() {
  echo "[warn] $*"
}

run_if_exists() {
  if command -v "$1" >/dev/null 2>&1; then
    shift
    "$@"
  fi
}

# Toggle with: DOTFILES_SKIP_SYSTEM_UPDATES=1 ~/.dotfiles/update.sh
SKIP_SYSTEM_UPDATES="${DOTFILES_SKIP_SYSTEM_UPDATES:-0}"

# Toggle with: DOTFILES_AUTO_PUSH=0 ~/.dotfiles/update.sh
AUTO_PUSH="${DOTFILES_AUTO_PUSH:-1}"

# Toggle with: DOTFILES_UPDATE_NPM_GLOBALS=1 ~/.dotfiles/update.sh
UPDATE_NPM_GLOBALS="${DOTFILES_UPDATE_NPM_GLOBALS:-0}"

log "Syncing dotfiles repo..."
current_branch="$(git -C "$DOTFILES" branch --show-current)"
if [ -z "$current_branch" ]; then
  warn "Could not determine current branch."
else
  log "Branch: $current_branch"
fi

# Auto-stash local edits so pull/rebase can succeed on busy machines.
auto_stashed=0
if [ -n "$(git -C "$DOTFILES" status --porcelain)" ]; then
  log "Stashing uncommitted local changes..."
  git -C "$DOTFILES" stash push -u -m "dotfiles-update-autostash $(date +%Y-%m-%dT%H:%M:%S)" >/dev/null
  auto_stashed=1
fi

log "Fetching and rebasing from origin..."
git -C "$DOTFILES" fetch --prune origin
if [ -n "$current_branch" ]; then
  git -C "$DOTFILES" pull --rebase origin "$current_branch"
else
  git -C "$DOTFILES" pull --rebase
fi

if [ "$auto_stashed" -eq 1 ]; then
  log "Reapplying stashed local changes..."
  if ! git -C "$DOTFILES" stash pop >/dev/null; then
    warn "Stash pop had conflicts. Resolve in $DOTFILES and continue manually."
    exit 1
  fi
fi

if [ "$AUTO_PUSH" = "1" ]; then
  ahead_count="$(git -C "$DOTFILES" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  if [ "$ahead_count" -gt 0 ]; then
    log "Pushing $ahead_count local commit(s) to origin..."
    git -C "$DOTFILES" push
  fi
fi

log "Refreshing symlinks..."
ln -sf "$DOTFILES/.zshrc" ~/.zshrc
ln -sf "$DOTFILES/.tmux.conf" ~/.tmux.conf
ln -sf "$DOTFILES/.vimrc" ~/.vimrc
ln -sf "$DOTFILES/.hyper.js" ~/.hyper.js
mkdir -p ~/.claude
ln -sf "$DOTFILES/claude/CLAUDE.md" ~/.claude/CLAUDE.md
ln -sf "$DOTFILES/claude/settings.local.json" ~/.claude/settings.local.json
ln -sf "$DOTFILES/claude/statusline-command.sh" ~/.claude/statusline-command.sh
rm -rf ~/.claude/skills
ln -sf "$DOTFILES/claude/skills" ~/.claude/skills

log "Ensuring scripts are executable..."
chmod +x "$DOTFILES/update.sh"
chmod +x "$DOTFILES/setup.sh"
if [ -d "$DOTFILES/scripts" ]; then
  find "$DOTFILES/scripts" -type f -name '*.sh' -exec chmod +x {} \;
fi

log "Updating runtime tools..."
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
fi
npm install -g @openai/codex

if [ "$UPDATE_NPM_GLOBALS" = "1" ]; then
  log "Updating global npm packages..."
  npm update -g || true
fi

if [ "$SKIP_SYSTEM_UPDATES" != "1" ]; then
  if command -v brew >/dev/null 2>&1; then
    log "Ensuring required brew packages are installed..."
    REQUIRED_BREW_PACKAGES=(
      gh
      zsh
      tmux
      pure
      fzf
      zsh-autosuggestions
      zsh-syntax-highlighting
      universal-ctags
      ripgrep
      fd
    )
    for pkg in "${REQUIRED_BREW_PACKAGES[@]}"; do
      brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg" || true
    done

    log "Updating Homebrew formulas/casks..."
    brew update
    brew upgrade
    brew upgrade --cask || true
    brew cleanup
  fi
fi

log "Syncing fzf shell integration..."
if command -v brew >/dev/null 2>&1; then
  FZF_PREFIX="$(brew --prefix fzf 2>/dev/null || true)"
  if [ -n "$FZF_PREFIX" ] && [ -x "$FZF_PREFIX/install" ]; then
    "$FZF_PREFIX/install" --all --no-bash --no-fish || true
  fi
fi

log "Copying vim color schemes..."
mkdir -p ~/.vim/colors
cp "$DOTFILES"/vim/colors/*.vim ~/.vim/colors/ 2>/dev/null || true

log "Installing vim plugins..."
vim +PlugInstall +qall 2>/dev/null || true

log "Reloading tmux config..."
if [ -n "${TMUX:-}" ]; then
  tmux source-file ~/.tmux.conf
  echo "    tmux reloaded"
else
  echo "    (tmux not running, config will load on next session)"
fi

log "Done"
echo ""
echo "Tip: add this alias in your zsh config: alias up='~/.dotfiles/update.sh'"
