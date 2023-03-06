git_clone() {
  PROVIDER=$1
  VENDOR=$2
  PROJECT=$3

  mkdir -p $HOME/Projects/$VENDOR
  cd $HOME/Projects/$VENDOR
  git clone git@$PROVIDER:$VENDOR/$PROJECT.git
  cd $PROJECT
}

gr() {
  git restore --staged "$@" && git status
}

ga() {
  git add "$@" && git status
}

alias g="git"
alias ghc="git_clone github.com"
alias glc="git_clone gitlab.com"
alias gs="git status"
alias gap="git add -p && git status"
alias gam="git add -u && git status"
alias gaa="git add -A && git status"
alias gd="git diff"
alias gdc="git diff --cached"
alias gpl="git pull"
alias gplo="git pull origin"
alias gps="git push"
alias gpso="git push origin"
alias gb="git branch"
alias gc="git checkout"
alias gnb="git checkout -b"
alias gcm="git commit -m"
alias gra="gr ."
alias gsh="git show"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

