#!/bin/bash

DIRECTORY=$HOME/.quotatis
if [ ! -d "$DIRECTORY" ]; then
  exit 0
fi

for f in $DIRECTORY/dot_bash.d/*; do
  ln -sf $f $HOME/.bash.d/$(basename $f)
done

