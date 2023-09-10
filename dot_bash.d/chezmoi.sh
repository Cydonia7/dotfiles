alias c="chezmoi" # Alias for chezmoi
alias cc="chezmoi cd" # Go into chezmoi's directory
alias cu="chezmoi update && source $HOME/.bashrc" # Pull changes from the repository, apply and reload
alias cad="chezmoi add && source $HOME/.bashrc" # Add file to chezmoi
alias ca="chezmoi apply && source $HOME/.bashrc" # Apply changes and reload bashrc
alias car="chezmoi apply -R && source $HOME/.bashrc" # Fetch repositories, apply changes and reload bashrc
alias cv="nvim $HOME/.config/chezmoi/chezmoi.yaml && chezmoi apply -R && source $HOME/.bashrc" # Edit variables, apply and reload

# Edit source file
ce()
{
  if [ $# -eq 0 ]; then
    file=$(chezmoi list --path-style=absolute | fzf --height 40% --reverse --border --prompt="Select the file you want to edit: ")
  else
    file=$(chezmoi list --path-style=absolute | fzf -q "$@" -1 -0 --height 40% --reverse --border --prompt="Select the file you want to edit: ")
  fi
  handle_error "No file selected"
  chezmoi edit $file -a
  source $HOME/.bashrc
}

# Edit source file then apply and reload bashrc
cea()
{
  ce $1 && ca
}

