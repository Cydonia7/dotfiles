ensure_repo() {
  local target_dir="$1" # e.g. "$HOME/.bin/airstatus"
  local repo_url="$2"   # e.g. "https://github.com/delphiki/AirStatus.git"

  if [[ ! -d "$target_dir/.git" ]]; then
    echo "→ Cloning $repo_url to $target_dir"
    mkdir -p "$(dirname "$target_dir")"
    git clone --depth 1 "$repo_url" "$target_dir"
  else
    echo "✓ Repo already present at $target_dir"
  fi
}

airstatus() {
  local repo="$HOME/.bin/airstatus"

  (
    set -euo pipefail
    ensure_repo "$repo" "https://github.com/delphiki/AirStatus.git"

    # Ensure uv is installed
    if ! command -v uv &>/dev/null; then
      echo "→ Installing uv with yay…"
      yay -S uv --noconfirm
    fi

    # Make the app runnable via uv (idempotent)
    (cd "$repo" && uv add --requirements requirements.txt --script main.py)
  )

  echo "→ Running AirStatus with uv"
  uv run "$repo/main.py"
}

alias as=airstatus
