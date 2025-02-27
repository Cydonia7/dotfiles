#!/bin/bash

DB_PATH="$HOME/.cache/evolution/mail"
UNREAD_COUNT=0

# Define folders to ignore (e.g., Spam, Trash, Drafts)
IGNORE_FOLDERS=("Spam" "Corbeille" "Brouillons" "[Gmail]/All Mail" "[Gmail]/Tous les messages")

# Loop through all Evolution mail databases
for DB in "$DB_PATH"/*/folders.db; do
  if [ -f "$DB" ]; then
    # Get the list of folder names from the "folders" table
    FOLDERS=$(sqlite3 "$DB" "SELECT folder_name FROM folders;")

    # Iterate through each folder and get the unread count
    while read -r FOLDER; do
      # Skip ignored folders
      skip=0
      for IGN in "${IGNORE_FOLDERS[@]}"; do
        if [[ "$FOLDER" == *"$IGN"* ]]; then
          skip=1
          break
        fi
      done
      if [ $skip -eq 0 ]; then
        COUNT=$(sqlite3 "$DB" "SELECT SUM(1 - read) FROM \"$FOLDER\";")
        UNREAD_COUNT=$((UNREAD_COUNT + COUNT))
      fi
    done <<<"$FOLDERS"
  fi
done

if [[ "$UNREAD_COUNT" == "0" ]]; then
  echo "$UNREAD_COUNT"
else
  echo "%{F#df8e1d} $UNREAD_COUNT"
fi
