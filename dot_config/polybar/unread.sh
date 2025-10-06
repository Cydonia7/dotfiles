#!/bin/bash

DB_PATH="$HOME/.cache/evolution/mail"
UNREAD_COUNT=0

# Define folders to ignore (e.g., Spam, Trash, Drafts)
IGNORE_FOLDERS=("Spam" "Corbeille" "Brouillons" "[Gmail]/All Mail" "[Gmail]/Tous les messages")

# Loop through all Evolution mail databases
for DB in "$DB_PATH"/*/folders.db; do
  if [ -f "$DB" ]; then
    # Build SQL WHERE clause to exclude ignored folders
    WHERE_CLAUSE=""
    for IGN in "${IGNORE_FOLDERS[@]}"; do
      if [ -n "$WHERE_CLAUSE" ]; then
        WHERE_CLAUSE="$WHERE_CLAUSE AND "
      fi
      WHERE_CLAUSE="${WHERE_CLAUSE}folder_name NOT LIKE '%${IGN}%'"
    done

    # Get sum of unread_count from folders table, excluding ignored folders
    COUNT=$(sqlite3 "$DB" "SELECT SUM(unread_count) FROM folders WHERE $WHERE_CLAUSE;")

    # Handle null/empty results
    if [ -n "$COUNT" ] && [ "$COUNT" != "" ]; then
      UNREAD_COUNT=$((UNREAD_COUNT + COUNT))
    fi
  fi
done

if [[ "$UNREAD_COUNT" == "0" ]]; then
  echo "$UNREAD_COUNT"
else
  echo "%{F#df8e1d} $UNREAD_COUNT"
fi
