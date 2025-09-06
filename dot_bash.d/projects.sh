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
alias rabr="rab && ldrar"

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
  # Rebase toutes les branches locales qui n'intègrent pas encore la branche spécifiée (ou master/main),
  # en les rebasant sur cette branche, puis push --force-with-lease.

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Pas dans un dépôt git."
    return 1
  fi

  local target_branch="$1"
  
  # Si aucune branche spécifiée, utiliser master ou main
  if [[ -z "$target_branch" ]]; then
    if git rev-parse --verify master &>/dev/null; then
      target_branch="master"
    elif git rev-parse --verify main &>/dev/null; then
      target_branch="main"
    else
      echo "Erreur : aucune branche 'master' ou 'main' trouvée."
      echo "Usage : rab [branche]"
      return 1
    fi
  else
    # Vérifier que la branche spécifiée existe
    if ! git rev-parse --verify "$target_branch" &>/dev/null; then
      echo "Erreur : la branche '$target_branch' n'existe pas."
      return 1
    fi
  fi
  
  local cur="$target_branch"
  
  # Sauvegarder la branche actuelle pour y revenir après
  local original_branch
  original_branch=$(git rev-parse --abbrev-ref HEAD) || return 1
  
  # Checkout de la branche cible pour s'assurer d'avoir son état le plus récent
  if [[ "$original_branch" != "$target_branch" ]]; then
    echo "Checkout de la branche '$target_branch'..."
    if ! git checkout "$target_branch"; then
      echo "Erreur : impossible de checkout la branche '$target_branch'."
      return 1
    fi
  fi

  # Trouver les branches locales qui N'ont PAS encore la branche courante dans leur historique
  mapfile -t _all_branches < <(git for-each-ref --format='%(refname:short)' refs/heads/)
  local candidates=()
  for b in "${_all_branches[@]}"; do
    [[ "$b" == "$cur" ]] && continue
    # si la branche courante N'est PAS ancêtre de b, b a besoin d'un rebase
    if ! git merge-base --is-ancestor "$cur" "$b"; then
      candidates+=("$b")
    fi
  done

  if ((${#candidates[@]} == 0)); then
    echo "Aucune branche à rebaser sur '$cur'."
    git checkout "$original_branch" &>/dev/null || true
    return 0
  fi

  ensure_gum || return 1

  local selected_flags=()
  for b in "${candidates[@]}"; do
    selected_flags+=(--selected "$b")
  done

  local selection
  selection=$(printf '%s\n' "${candidates[@]}" | gum choose --no-limit "${selected_flags[@]}")
  if [[ -z "$selection" ]]; then
    echo "Rien de sélectionné, abandon."
    git checkout "$original_branch" &>/dev/null || true
    return 1
  fi

  local ok_list=()
  local fail_list=()

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

  # Retourner à la branche d'origine
  git checkout "$original_branch" &>/dev/null || true

  echo
  echo "===== Résumé ====="
  ((${#ok_list[@]})) && echo "✔️  Rebasées & poussées : ${ok_list[*]}"
  ((${#fail_list[@]})) && echo "❌ À traiter manuellement : ${fail_list[*]}"
}
