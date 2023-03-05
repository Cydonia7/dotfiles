#!/bin/bash

DIRECTORY=$HOME/.quotatis
if [ ! -d "$DIRECTORY" ]; then
  exit 0
fi

source $DIRECTORY/install.sh

