#!/bin/bash

screen_locked() { pgrep -x i3lock >/dev/null; }

while true; do
  # If i3lock is running, poll until it disappears
  while screen_locked; do sleep 5; done

  HOUR=$(date +%-H)

  if ((HOUR >= 7 && HOUR < 20)); then
    img="$HOME/Images/background.png"
  else
    img="$HOME/Images/background-night.png"
  fi

  feh --no-fehbg --bg-scale "$img" "$img"

  # Check every 15 minutes
  sleep 900
done
