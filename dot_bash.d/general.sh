eval "$(zoxide init bash --hook prompt)"
eval "$(keychain --eval -q)"
eval "$(starship init bash)"

source /usr/share/fzf/key-bindings.bash

alias sa="ssh-add"
alias sl="keychain -l"

