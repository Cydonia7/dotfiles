#!/bin/bash

screen_locked() { pgrep -x i3lock >/dev/null; }

while true; do
  # If i3lock is running, poll until it disappears
  while screen_locked; do sleep 5; done

  # Wait a moment for monitors to fully wake up after unlock
  if ! screen_locked; then
    sleep 2
    # Wait until we have the expected number of monitors
    for i in {1..10}; do
      monitor_count=$(xrandr --listmonitors 2>/dev/null | grep -c "^ [0-9]:" || echo 0)
      if [ "$monitor_count" -ge 2 ]; then
        break
      fi
      sleep 0.5
    done
  fi

  HOUR=$(date +%-H)

  if ((HOUR >= 7 && HOUR < 20)); then
    img="$HOME/Images/background.png"
  else
    img="$HOME/Images/background-night.png"
  fi

  # Use --bg-fill instead of --bg-scale for better multi-monitor handling
  # This centers and fills each monitor independently
  feh --no-fehbg --bg-fill "$img"

  # Check every 15 minutes
  sleep 900
done
