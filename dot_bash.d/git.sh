#private
git_clone() {
  PROVIDER=$1
  VENDOR=$2
  PROJECT=$3

  mkdir -p $HOME/Projects/$VENDOR
  cd $HOME/Projects/$VENDOR
  git clone git@$PROVIDER:$VENDOR/$PROJECT.git
  cd $PROJECT
}

alias g="git" # Alias for git

## Fetch data from server
alias ghc="git_clone github.com" # Clone from Github
alias glc="git_clone gitlab.com" # Clone from Gitlab

# Clone full Github organization
function gclo() {
  if [[ -z $1 ]]; then
    echo "Usage: gclo <org_name>"
    return 1
  fi

  org_name="$1"
  remembered_file=".$1_remembered_repos"

  if [[ ! -f $remembered_file ]]; then
    touch $remembered_file
  fi

  GREEN="\033[0;32m"
  YELLOW="\033[1;33m"
  RESET="\033[0m"

  gh repo list $org_name -L 500 --json nameWithOwner -q '.[].nameWithOwner' | while read -r repo; do
    answer=$(grep "^$repo=" $remembered_file | cut -d '=' -f 2)

    if [[ -z $answer ]]; then
      while true; do
        echo -en "${YELLOW}Do you want to clone $repo? (y/n/o)${RESET} "
        read -rs -n1 user_answer < /dev/tty
        echo $user_answer
        if [[ $user_answer == "y" ]] || [[ $user_answer == "n" ]]; then
          answer=$user_answer
          echo "$repo=$answer" >> $remembered_file
          break
        elif [[ $user_answer == "o" ]]; then
          xdg-open "https://github.com/$repo" >/dev/null 2>&1 &
        else
          echo "Invalid input, please press 'y', 'n', or 'o'"
        fi
      done
    fi
  done

  while read -r line; do
    repo=$(echo "$line" | cut -d '=' -f 1)
    answer=$(echo "$line" | cut -d '=' -f 2)

    if [[ $answer == "y" ]]; then
      vendor=$(echo $repo | cut -d '/' -f 1)
      project=$(echo $repo | cut -d '/' -f 2)
      target_dir="$HOME/Projects/$vendor/$project"

      if [[ -d $target_dir ]]; then
        echo -e "${GREEN}Skipping $repo because the folder already exists.${RESET}"
      else
        echo -e "${GREEN}Cloning $repo...${RESET}"
        (git_clone github.com $vendor $project)
      fi
    else
      echo -e "${GREEN}Skipping $repo${RESET}"
    fi
  done < $remembered_file
}

alias gf="git fetch --prune" # Fetch from the server
alias gfo="git fetch origin --prune" # Fetch origin
alias gfa="git fetch --all --prune" # Fetch all remotes
alias gpl="git pull" # Pull
alias gplo="git pull origin" # Pull from origin

# Checkout remote branch
gcr() {
  if [[ -z "$1" ]]; then
    git fetch origin --prune && git branch -r | grep -v "HEAD" | grep origin/ | fzf --height=50% --reverse --info=inline | sed 's/origin\///' | xargs git checkout
  else
    git checkout "$@"
  fi
}

## Push work to the server

# Add files to staging area
ga() {
  git add "$@" && git status
}

alias gap="git add -N . && git add -p && git status" # Add patches
alias gam="git add -u && git status" # Add modified files
alias gaa="git add -A && git status" # Add everything
alias gcl="git clean -fdx && git status" # Clean the working dir

alias gra="gr ." # Restore everything

# Restore specific files
gr() {
  git restore --staged "$@" && git status
}

alias gst="git stash" # Stash changes
alias gstp="git stash pop" # Pop stash changes
alias gcm="git commit -m" # Commit
alias gca="git commit --amend" # Amend previous commit
alias gcan="git commit --amend --no-edit" # Amend previous commit without editing
alias gad='LC_ALL=C GIT_COMMITTER_DATE="$(date)" git commit --amend --no-edit --date "$(date)"' # Amend previous commit date
alias gps="git push" # Push changes
alias gpso="git push origin" # Push to origin
alias gpsof="git push origin --force-with-lease" # Push to origin, force with lease

## Inspect repository

alias gs="git status" # Show status
alias gd="git diff" # Show diff
alias gdc="git diff --cached" # Show cached diff
alias gsh="git show" # Show commit
alias gshh="git show HEAD" # Show HEAD
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit" # Shows history
alias gla="gl --all"
alias gsp='git standup' # Shows my recent commits

## Branch operations

# Checkout branch
gc() {
  if [[ -z "$1" ]]; then
    git branch | grep -v "^\*" | fzf --height=20% --reverse --info=inline | xargs git checkout
  else
    git checkout "$@"
  fi
}

alias gb="git branch" # List branches
alias gba="git branch -a" # List all branches
alias gnb="git checkout -b" # Checkout new branch

# Erase current branch
gec() {
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  git checkout ${default_branch}
  git branch -D ${current_branch}
}

# Delete a branch
gbd() {
  if [[ -z "$1" ]]; then
    git branch | grep -v "^\*" | fzf --height=50% --reverse --info=inline | xargs git branch -D
  else
    git branch -D "$@"
  fi
}

alias grb="git rebase" # Rebase onto branch
alias grbc="git rebase --continue" # Continue rebase
alias grba="git rebase --abort" # Abort rebase

