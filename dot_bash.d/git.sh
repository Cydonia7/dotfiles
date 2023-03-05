gc() {
  PROVIDER=$1
  VENDOR=$2
  PROJECT=$3

  mkdir -p $HOME/Projects/$VENDOR
  cd $HOME/Projects/$VENDOR
  git clone git@$PROVIDER:$VENDOR/$PROJECT.git
  cd $PROJECT
}

alias ghc="gc github.com"
alias glc="gc gitlab.com"

