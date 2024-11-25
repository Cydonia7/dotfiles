#!/bin/bash

set -euo pipefail

declare -A LOG_PRIORITIES=(
    [DEBUG]=1
    [INFO]=2
    [WARNING]=3
    [ERROR]=4
)
declare -A LOG_COLORS=(
    [DEBUG]="4"
    [INFO]="2"
    [WARNING]="3"
    [ERROR]="1"
)

LOG_LEVEL=${LOG_LEVEL:-WARNING}
LOG_LEVEL=${LOG_LEVEL^^}

function log::set_log_level {
    local new_level=${1^^}
    if [[ -n ${LOG_PRIORITIES[$new_level]+x} ]]; then
        LOG_LEVEL=$new_level
    else
        error "Invalid log level: $new_level"
    fi
}

function log::debug {
    log "DEBUG" "$1"
}

function log::info {
    log "INFO" "$1"
}

function log::warning {
    log "WARNING" "$1"
}

function log::error {
    log "ERROR" "$1"
}

function log {
    local level=$1
    local message=$2

    local current_priority=${LOG_PRIORITIES[$LOG_LEVEL]}
    local message_priority=${LOG_PRIORITIES[$level]}

    if [[ $message_priority -ge $current_priority ]]; then
        local color=${LOG_COLORS[$level]}

        while IFS= read -r line; do
            printf "\x1b[48;2;50;50;50m $(date +%H:%M:%S) \x1b[4${color}m  \x1b[0;3${color}m ${line}\x1b[0m\n" >&2
        done <<< "$message"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log::debug "This is a debug message"
    log::info "This is an info message"
    log::warning "This is a warning message"
    log::error $'This is an error message:\nIt includes details'
    log::set_log_level DEBUG
    log::debug "Debug message after setting log level manually"
fi

