#!/bin/sh

if [ ! -d "$HOME/.config/nvim" ]; then
  git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

cd ~/.local/share/chezmoi/dot_config/nvim/lua/plugins
for f in *; do
  ln -sf ~/.local/share/chezmoi/dot_config/nvim/lua/plugins/$f ~/.config/nvim/lua/plugins/$f
done
rm -f ~/.config/nvim/lua/plugins/example.lua

cd ~/.local/share/chezmoi/dot_config/nvim/lua/config
for f in *; do
  ln -sf ~/.local/share/chezmoi/dot_config/nvim/lua/config/$f ~/.config/nvim/lua/config/$f
done
