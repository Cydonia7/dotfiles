#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TMP_ERROR_FILE=/tmp/$$.error

handle_error() {
    if [ $? -ne 0 ]; then
        log "ERROR" "$1. Aborting..."
        if [ -f $TMP_ERROR_FILE ]; then
            cat $TMP_ERROR_FILE
            rm -f $TMP_ERROR_FILE
        fi
        kill -INT $$
    else
        rm -f $TMP_ERROR_FILE
    fi
}

handle_result() {
    handle_error "$2"
    log "SUCCESS" "$1"
}

log() {
    local log_level="$1"
    local message="$2"

    # Log level to color code mapping
    local color
    if [ "$log_level" == "SUCCESS" ]; then
        color="$GREEN"
    elif [ "$log_level" == "ERROR" ]; then
        color="$RED"
    elif [ "$log_level" == "INFO" ]; then
        color="$BLUE"
    else
        color="$NC"
    fi

    echo -e "${color}[$log_level]${NC} $message"
}

run() {
    "$@" >/dev/null 2>$TMP_ERROR_FILE
}
