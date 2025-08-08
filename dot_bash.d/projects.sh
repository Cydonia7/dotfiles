# Localhost helper
alias lh="bash $HOME/.bin/localhost"

ensure_gum() {
  # Vérifie/installe gum (réutilisable)
  if command -v gum &>/dev/null; then
    return 0
  fi

  echo "gum introuvable, installation…"
  if command -v go &>/dev/null; then
    go install github.com/charmbracelet/gum@latest
    # Ajoute $HOME/go/bin au PATH si besoin (nouvelle session conseillée)
    if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
      export PATH="$HOME/go/bin:$PATH"
    fi
  else
    echo "Erreur : Go n'est pas installé. Installe Go pour utiliser gum."
    return 1
  fi

  if ! command -v gum &>/dev/null; then
    echo "Erreur : échec de l'installation de gum. Installe-le manuellement."
    return 1
  fi
}

# Lycra
alias zl="cd /home/cydo/Projects/hiway/lycra"
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
alias ldrar="ldra deploy -f same_branch"

# Lycra deploy run choose - interactive context selection with gum
ldrc() {
  ensure_gum || return 1

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

# Rebase all branches
rab() {
  # Rebase toutes les branches locales dont la pointe est un ancêtre de la branche courante,
  # en les rebasant sur la branche courante, puis push --force-with-lease.

  # Sécurité : être dans un repo git
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Pas dans un dépôt git."
    return 1
  fi

  local cur
  cur=$(git rev-parse --abbrev-ref HEAD) || return 1

  # Liste des branches locales candidates : ancêtres de HEAD (sauf HEAD)
  mapfile -t _all_branches < <(git for-each-ref --format='%(refname:short)' refs/heads/)
  local candidates=()
  for b in "${_all_branches[@]}"; do
    [[ "$b" == "$cur" ]] && continue
    # Si la pointe de $b est ancêtre de la branche courante
    if git merge-base --is-ancestor "$(git rev-parse "$b")" "$cur"; then
      candidates+=("$b")
    fi
  done

  if ((${#candidates[@]} == 0)); then
    echo "Aucune branche locale ne pointe vers un ancêtre de '$cur'."
    return 0
  fi

  # S'assure que gum est là
  ensure_gum || return 1

  # Pré-sélectionne tout par défaut dans gum
  local selected_flags=()
  for b in "${candidates[@]}"; do
    selected_flags+=(--selected "$b")
  done

  local selection
  selection=$(printf '%s\n' "${candidates[@]}" | gum choose --no-limit "${selected_flags[@]}")
  if [[ -z "$selection" ]]; then
    echo "Rien de sélectionné, abandon."
    return 1
  fi

  # Pour le résumé final
  local ok_list=()
  local fail_list=()

  # Rebase chaque branche sélectionnée sur la branche courante
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    echo
    echo "==> Rebase '$branch' sur '$cur'…"
    if ! git checkout "$branch"; then
      echo "   ⚠️  Impossible de se placer sur '$branch'."
      fail_list+=("$branch (checkout)")
      continue
    fi

    if git rebase "$cur"; then
      if git push --force-with-lease origin "$branch"; then
        echo "   ✅ Rebasée et poussée : $branch"
        ok_list+=("$branch")
      else
        echo "   ⚠️  Push échoué pour '$branch'."
        fail_list+=("$branch (push)")
      fi
    else
      echo "   ⚠️  Conflit détecté sur '$branch'. Rebase abandonné."
      git rebase --abort || true
      fail_list+=("$branch (conflit)")
    fi
  done <<<"$selection"

  # Retour sur la branche d'origine
  git checkout "$cur" &>/dev/null || true

  echo
  echo "===== Résumé ====="
  ((${#ok_list[@]})) && echo "✔️  Rebasées & poussées : ${ok_list[*]}"
  ((${#fail_list[@]})) && echo "❌ À traiter manuellement : ${fail_list[*]}"
}
