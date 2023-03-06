alias c="chezmoi"
alias ca="chezmoi apply && source $HOME/.bashrc"
alias car="chezmoi apply -R && source $HOME/.bashrc"

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

