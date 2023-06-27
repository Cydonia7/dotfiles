#!/bin/bash

DIRECTORY=$HOME/.quotatis
if [ -d "$DIRECTORY" ]; then
  source $DIRECTORY/install.sh
fi

DIRECTORY=$HOME/.cmi
if [ -d "$DIRECTORY" ]; then
  source $DIRECTORY/install.sh
fi

