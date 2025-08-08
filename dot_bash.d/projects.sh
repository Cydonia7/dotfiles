# Localhost helper
alias lh="bash $HOME/.bin/localhost"

# Lycra
alias zla="cd /home/cydo/Projects/hiway/lycra"
alias zla="cd /home/cydo/Projects/hiway/lycra/application"
alias zld="cd /home/cydo/Projects/hiway/lycra/infrastructure/deploy"

# Lycra deploy run
ldr() {
  (
    zld
    ./$@
  )
}

alias ldra="APP_CONTEXT=all ldr"
alias ldrp="APP_CONTEXT=prod ldr"
alias ldrpp="APP_CONTEXT=preprod ldr"
alias ldrs="APP_CONTEXT=tdf-staging ldr"
alias ldrd="APP_CONTEXT=tdf-dev ldr"

# Lycra deploy run choose - interactive context selection with gum
ldrc() {
  # Check if gum is available, install if not
  if ! command -v gum &>/dev/null; then
    echo "gum not found, installing..."
    if command -v go &>/dev/null; then
      go install github.com/charmbracelet/gum@latest
      # Add Go bin to PATH if not already there
      if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
        export PATH="$HOME/go/bin:$PATH"
      fi
    else
      echo "Error: Go is not installed. Please install Go first to use ldrc."
      return 1
    fi

    # Check again after installation
    if ! command -v gum &>/dev/null; then
      echo "Error: Failed to install gum. Please install it manually."
      return 1
    fi
  fi

  # Get available contexts
  local contexts=("prod" "preprod" "tdf-staging" "tdf-dev")

  # Use gum choose to select contexts (multi-select with no limit)
  local selected_contexts=$(printf '%s\n' "${contexts[@]}" | gum choose --no-limit)

  # Exit if no selection was made
  if [ -z "$selected_contexts" ]; then
    echo "No contexts selected. Exiting."
    return 1
  fi

  # Convert newline-separated selections to comma-separated
  local comma_separated=$(echo "$selected_contexts" | tr '\n' ',' | sed 's/,$//')

  # Run the command with the selected contexts
  APP_CONTEXT="$comma_separated" ldr "$@"
}

_ldr_completion() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD - 1]}
  local blacklist_patterns='config|src|setup|settings'

  # Save current directory
  local original_dir=$(pwd)

  # Move to the target directory to get the relevant file and folder names
  cd /home/cydo/Projects/hiway/lycra/infrastructure/deploy 2>/dev/null

  # Check if we're completing arguments for the deploy command
  if [[ "${COMP_WORDS[@]}" =~ "deploy" ]] && [[ $COMP_CWORD -gt 1 ]]; then
    # If previous word is deploy, or we already have -f flag and deploy is in the command
    if [[ "$prev" == "deploy" ]] || ([[ "${COMP_WORDS[@]}" =~ "-f" ]] && [[ "${COMP_WORDS[@]}" =~ "deploy" ]]); then
      # Move to the application directory to get git branches
      cd /home/cydo/Projects/hiway/lycra/application 2>/dev/null

      # Get local branches only
      local local_branches=$(git branch 2>/dev/null | sed 's/^[* ]*//' | grep -v '^(' || true)

      # Filter based on current input
      COMPREPLY=($(compgen -W "$local_branches" -- "$cur"))
    else
      # For other arguments or if -f flag is expected
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-f" -- "$cur"))
      else
        # Default file/directory completion, excluding blacklisted patterns
        COMPREPLY=($(compgen -f -- "$cur" | grep -Ev "$blacklist_patterns"))
      fi
    fi
  else
    # Default behavior for non-deploy commands
    COMPREPLY=($(compgen -f -- "$cur" | grep -Ev "$blacklist_patterns"))
  fi

  # Return to the original directory
  cd "$original_dir" 2>/dev/null
}

complete -F _ldr_completion ldr
complete -F _ldr_completion ldra
complete -F _ldr_completion ldrp
complete -F _ldr_completion ldrpp
complete -F _ldr_completion ldrs
complete -F _ldr_completion ldrd
complete -F _ldr_completion ldrc
