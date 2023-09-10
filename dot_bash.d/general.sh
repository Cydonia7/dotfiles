eval "$(zoxide init bash --hook prompt)"
eval "$(keychain --eval -q)"
eval "$(starship init bash)"

source /usr/share/fzf/key-bindings.bash

alias sa="ssh-add" # Add key to the SSH agent
alias sl="keychain -l" # List keys in the SSH agent

