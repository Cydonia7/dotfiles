#!/bin/bash

while true; do
  HOUR=$(date +'%H')

  if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 20 ]; then
    feh --bg-scale ~/Images/background.png
  else
    feh --bg-scale ~/Images/background-night.png
  fi

  # Check every 15 minutes
  sleep 900
done
