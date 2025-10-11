eval "$(keychain --eval -q)"
eval "$(starship init bash)"

source /usr/share/fzf/key-bindings.bash

alias sa="ssh-add"     # Add key to the SSH agent
alias sl="keychain -l" # List keys in the SSH agent
alias eb="exec bash"
alias cb="xclip -sel clipboard"

eval "$(zoxide init bash)"

eval -- "$(/usr/bin/starship init bash --print-full-init)"
eval $(fzf --bash)
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"
source /usr/share/fzf/key-bindings.bash

# cd puis eza en colonnes (couleurs+icônes), rapide, avec limite & timeout
cl() {
  local dir="${1:-.}"
  builtin cd -- "$dir" || return

  # Timeout plus court sur FS réseau
  local fstype timeout_s
  if command -v stat >/dev/null 2>&1; then
    fstype=$(stat -f -c %T . 2>/dev/null || stat -f %T . 2>/dev/null)
  fi
  case "$fstype" in
  nfs* | cifs | smbfs | fuse.sshfs | glusterfs | afs) timeout_s="0.5s" ;;
  *) timeout_s="1s" ;;
  esac

  # Options eza :
  # --color=always + --icons pour la mise en forme même via pipe
  # --grid pour colonnes
  # -U pas de tri ; --group-directories-first pratique
  # -d (IMPORTANT) liste les dossiers EUX-MÊMES, pas leur contenu
  local WIDTH="${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}"
  local EZA_OPTS=(--color=always --icons --grid -U --group-directories-first -d --width="$WIDTH")

  local LIMIT=200

  # Trouver gfind/GNU find pour -printf (idéal), sinon fallback
  local FIND= find_printf=
  if command -v gfind >/dev/null 2>&1; then
    FIND=gfind
  else
    FIND=find
  fi
  if "$FIND" . -maxdepth 0 -printf '' >/dev/null 2>&1; then
    find_printf=1
  fi

  # timeout(1) dispo ?
  local TIMEOUT=
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT="timeout --preserve-status"
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT="gtimeout --preserve-status"
  fi

  if [[ -n "$find_printf" ]]; then
    # Limiter par ENTRÉES (NUL-delimited), puis passer ces noms à eza
    if command -v head >/dev/null 2>&1 && head -z </dev/null >/dev/null 2>&1; then
      # chemin le plus propre (GNU head -z)
      if [[ -n "$TIMEOUT" ]]; then
        eval "$TIMEOUT \"$timeout_s\" bash -c '
          $FIND . -maxdepth 1 -mindepth 1 -printf \"%P\0\" 2>/dev/null \
          | head -z -n $LIMIT \
          | xargs -0 -r eza ${EZA_OPTS[*]} -- 2>/dev/null
        '"
      else
        bash -c '
          '"$FIND"' . -maxdepth 1 -mindepth 1 -printf "%P\0" 2>/dev/null \
          | head -z -n '"$LIMIT"' \
          | xargs -0 -r eza '"${EZA_OPTS[*]}"' -- 2>/dev/null
        '
      fi
    else
      # Fallback portable sans head -z : couper après N NULs avec awk
      if [[ -n "$TIMEOUT" ]]; then
        eval "$TIMEOUT \"$timeout_s\" bash -c '
          $FIND . -maxdepth 1 -mindepth 1 -printf \"%P\0\" 2>/dev/null \
          | awk -v RS=\"\\0\" -v ORS=\"\\0\" -v N=$LIMIT \"NR<=N\" \
          | xargs -0 -r eza ${EZA_OPTS[*]} -- 2>/dev/null
        '"
      else
        bash -c '
          '"$FIND"' . -maxdepth 1 -mindepth 1 -printf "%P\0" 2>/dev/null \
          | awk -v RS="\0" -v ORS="\0" -v N='"$LIMIT"' "NR<=N" \
          | xargs -0 -r eza '"${EZA_OPTS[*]}"' -- 2>/dev/null
        '
      fi
    fi
  else
    # Pas de -printf/-maxdepth fiable (ex: macOS sans gfind) → on s’appuie sur le timeout
    [[ -n "$TIMEOUT" ]] && $TIMEOUT "$timeout_s" eza "${EZA_OPTS[@]}" -- 2>/dev/null ||
      eza "${EZA_OPTS[@]}" -- 2>/dev/null
    echo "ℹ️ Installe 'findutils' (gfind) pour limiter proprement à $LIMIT entrées."
  fi
}
