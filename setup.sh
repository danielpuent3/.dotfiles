#!/bin/bash

#install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

#symlink zshrc and tmux 

ln -sf ~/.dotfiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.tmux.conf ~/.tmux.conf

source ~/.zshrc

#install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install --cask hyper

brew install gh

brew install zsh
$(brew --prefix)/bin/zsh

brew install tmux

brew install fig

cd ~/.dotfiles
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git

