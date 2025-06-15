#!/bin/bash

screen_locked() { pgrep -x i3lock >/dev/null; }

while true; do
  # If i3lock is running, poll until it disappears
  while screen_locked; do sleep 5; done

  HOUR=$(date +'%H')

  if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 20 ]; then
    feh --bg-scale ~/Images/background.png
  else
    feh --bg-scale ~/Images/background-night.png
  fi

  # Check every 15 minutes
  sleep 900
done
