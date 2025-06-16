eval "$(keychain --eval -q)"
eval "$(starship init bash)"

source /usr/share/fzf/key-bindings.bash

alias sa="ssh-add"     # Add key to the SSH agent
alias sl="keychain -l" # List keys in the SSH agent
alias eb="exec bash"
alias cb="xclip -sel clipboard"

eval "$(zoxide init bash)"
eval "$(atuin init bash)"

eval -- "$(/usr/bin/starship init bash --print-full-init)"
eval $(fzf --bash)
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"
source /usr/share/fzf/key-bindings.bash
