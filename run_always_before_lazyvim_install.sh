#!/bin/sh

NVIM_CONFIG="$HOME/.config/nvim"
CHEZMOI_CONFIG="$HOME/.local/share/chezmoi/dot_config/nvim"

if [ ! -d "$NVIM_CONFIG" ]; then
  git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"
  rm -f ~/.config/nvim/lua/plugins/example.lua
fi

find "$CHEZMOI_CONFIG" -type d | while read -r src_dir; do
  dest_dir="$NVIM_CONFIG${src_dir#$CHEZMOI_CONFIG}"
  mkdir -p "$dest_dir"

  for file in "$src_dir"/*; do
    if [ -f "$file" ]; then
      ln -sf "$file" "$dest_dir/$(basename "$file")"
    fi
  done
done
