alias l='eza -lbF --git --icons' # List current directory
alias ls='eza --icons'           # List current directory without styling
alias la='l -a'                  # List files including hidden

alias lt='eza --tree' # List files recursively

for i in {1..5}; do
  alias lt$i="lt --level=$i"
done

alias lp='lt $HOME/Projects' # List projects
