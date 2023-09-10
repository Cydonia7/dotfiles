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

## Clone
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

## Other operations

gr() {
  git restore --staged "$@" && git status
}

ga() {
  git add "$@" && git status
}

gc() {
  if [[ -z "$1" ]]; then
    git branch | grep -v "^\*" | fzf --height=20% --reverse --info=inline | xargs git checkout
  else
    git checkout "$@"
  fi
}

gcr() {
  if [[ -z "$1" ]]; then
    git fetch origin --prune && git branch -r | grep -v "HEAD" | grep origin/ | fzf --height=50% --reverse --info=inline | sed 's/origin\///' | xargs git checkout
  else
    git checkout "$@"
  fi
}

gbd() {
  if [[ -z "$1" ]]; then
    git branch | grep -v "^\*" | fzf --height=50% --reverse --info=inline | xargs git branch -D
  else
    git branch -D "$@"
  fi
}

# Erase current branch
gec() {
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  git checkout ${default_branch}
  git branch -D ${current_branch}
}

alias g="git"
alias gs="git status"
alias gap="git add -N . && git add -p && git status"
alias gam="git add -u && git status"
alias gaa="git add -A && git status"
alias gf="git fetch"
alias gfo="git fetch origin --prune"
alias gfa="git fetch --all --prune"
alias gd="git diff"
alias gdc="git diff --cached"
alias gpl="git pull"
alias gplo="git pull origin"
alias gps="git push"
alias gpso="git push origin"
alias gpsof="git push origin --force-with-lease"
alias gb="git branch"
alias gba="git branch -a"
alias gnb="git checkout -b"
alias gcm="git commit -m"
alias gca="git commit --amend"
alias gcan="git commit --amend --no-edit"
alias gra="gr ."
alias grb="git rebase"
alias grbc="git rebase --continue"
alias gsh="git show"
alias gshh="git show HEAD"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gcl="git clean -fdx && git status"
alias gad='LC_ALL=C GIT_COMMITTER_DATE="$(date)" git commit --amend --no-edit --date "$(date)"'
alias gsp='git standup'

