# Lycra
alias zla="cd /home/cydo/Projects/hiway/lycra/application"
alias zld="cd /home/cydo/Projects/hiway/lycra/infrastructure/deploy"

# Lycra deploy run
ldr() {
  (zld; $@)
}

alias ldra="APP_CONTEXT=all ldr"
alias ldrp="APP_CONTEXT=prod ldr"
alias ldrpp="APP_CONTEXT=preprod ldr"
alias ldrs="APP_CONTEXT=tdf-staging ldr"
alias ldrd="APP_CONTEXT=tdf-dev ldr"

_ldr_completion() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local blacklist_patterns='config|src|setup|settings'

  # Move to the target directory to get the relevant file and folder names
  cd /home/cydo/Projects/hiway/lycra/infrastructure/deploy 2>/dev/null

  # Generate a list of all files and directories, excluding the blacklisted patterns
  # and then filter this list based on the current word being completed
  COMPREPLY=($(compgen -f -- "$cur" | grep -Ev "$blacklist_patterns"))

  # Return to the original directory
  cd - > /dev/null 2>&1
}

complete -F _ldr_completion ldr

