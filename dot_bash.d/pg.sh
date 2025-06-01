#!/bin/bash

#private
select_database() {
  databases=$(psql -U postgres -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres'" -t)
  selected_db=$(echo "$databases" | fzf --height 40% --reverse --border --prompt="Select the database you want to $1: ")
  handle_error "No database selected"
  echo $selected_db
}

#private
compute_pg_dsn() {
  username=$1
  server_version=$(psql -U postgres -c "SHOW server_version" | tail +3 | head -n1 | xargs)

  echo "pgsql://$username:$username@localhost:5432/$username?serverVersion=$server_version"
}

#private
create_pg_db() {
  if [ -z "$1" ]; then
    read -p "Enter the new database name: " username
  else
    username="$1"
  fi

  psql -U postgres -c "CREATE USER $username WITH PASSWORD '$username';" >/dev/null 2>$TMP_ERROR_FILE
  handle_result "User $username created" "Could not create user $username"
  createdb -U postgres -O $username $username >/dev/null 2>$TMP_ERROR_FILE
  handle_result "Database $username created" "Could not create database $username"
  psql -U postgres -c "GRANT ALL PRIVILEGES ON SCHEMA public TO $username" >/dev/null 2>$TMP_ERROR_FILE
  handle_result "Privileges granted to $username" "Could not grant privileges to $username"
  log INFO "You can now use the following DSN to connect from Symfony apps:\n$(compute_pg_dsn $username)"
}

#private
info_pg_db() {
  # Get the username from argument or prompt
  if [ -z "$1" ]; then
    username=$(select_database)
    if [ $? -ne 0 ]; then
      return
    fi
  else
    username="$1"
  fi

  LOG_LEVEL=info log INFO "DSN : $(compute_pg_dsn $username)"
}

#private
drop_pg_db() {
  # Get the username from argument or prompt
  if [ -z "$1" ]; then
    username=$(select_database)
    if [ $? -ne 0 ]; then
      return
    fi
  else
    username="$1"
  fi

  psql -U postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$username';" >/dev/null 2>$TMP_ERROR_FILE
  handle_result "Connections to $username disconnected" "Could not disconnect all connections to $username"
  dropdb -U postgres $username >/dev/null 2>$TMP_ERROR_FILE
  handle_result "Database $username dropped" "Could not drop database $username"
  psql -U postgres -c "DROP OWNED BY $username" >/dev/null 2>$TMP_ERROR_FILE
  handle_result "Data owned by $username dropped" "Could not drop data owned by $username"
  dropuser -U postgres $username >/dev/null 2>$TMP_ERROR_FILE
  handle_result "User $username dropped" "Could not drop user $username"
}

#private
reset_pg_db() {
  # Get the username from argument or prompt
  if [ -z "$1" ]; then
    username=$(select_database)
    if [ $? -ne 0 ]; then
      return
    fi
  else
    username="$1"
  fi

  drop_pg_db $username
  create_pg_db $username
}

# Manage local PostgreSQL databases
pg() {
  local subcommand="$1"
  shift

  declare -A subcommands=(
    [create]=create_pg_db
    [drop]=drop_pg_db
    [info]=info_pg_db
    [reset]=reset_pg_db
  )

  declare -A usages=(
    [create]="pg create [name]"
    [drop]="pg drop [name]"
    [info]="pg info [name]"
    [reset]="pg reset [name]"
  )

  show_possible_subcommands() {
    local subcommands=("$@")
    echo "Possible subcommands are:"
    for key in "${!usages[@]}"; do
      echo "  ${usages[$key]}"
    done
  }

  if [[ -z "$subcommand" ]]; then
    show_possible_subcommands "${!subcommands[@]}"
    return 1
  fi

  if [[ -z "${subcommands[$subcommand]}" ]]; then
    echo "Error: Invalid subcommand $subcommand."
    show_possible_subcommands "${!subcommands[@]}"
    return 1
  fi

  "${subcommands[$subcommand]}" "$@"
}
