alias c="chezmoi"
alias cc="chezmoi cd"
alias cu="chezmoi update"
alias cad="chezmoi add"
alias ca="chezmoi apply && source $HOME/.bashrc"
alias car="chezmoi apply -R && source $HOME/.bashrc"
alias cv="nvim $HOME/.config/chezmoi/chezmoi.yaml && chezmoi apply -R"

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

cea()
{
  ce $1 && ca
}

