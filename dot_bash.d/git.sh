git_clone() {
  PROVIDER=$1
  VENDOR=$2
  PROJECT=$3

  mkdir -p $HOME/Projects/$VENDOR
  cd $HOME/Projects/$VENDOR
  git clone git@$PROVIDER:$VENDOR/$PROJECT.git
  cd $PROJECT
}

gcm() {
  git commit -m $@
}

alias g="git"
alias ghc="git_clone github.com"
alias glc="git_clone gitlab.com"
alias gs="git status"
alias ga="git add"
alias gd="git diff"
alias gdc="git diff --cached"
alias gpl="git pull"
alias gps="git push"
alias gb="git branch"
alias gc="git checkout"

