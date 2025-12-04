#!/bin/bash

#private
document_aliases_and_functions() {
    if [[ -z "$1" ]]
    then
        echo "Directory not provided"
        return 1
    fi

    cache_dir="$HOME/.dh_cache"
    mkdir -p "$cache_dir"

    # Make sure directory ends with '/'
    directory="${1%/}/"

    # List all files in the directory
    files=$(find "$directory" -type f)

    if [[ ! -z "$2" ]]; then
        # Filtering files if a second argument is provided
        files=$(echo "$files" | grep "$2")
    fi

    for file in $files; do
        filename=$(basename "$file")

        if [[ "$filename" == "0_framework.sh" ]]; then
            continue
        fi

        padding_length=$((24-${#filename}))
        padding=$(printf "%0.s " $(seq 1 $padding_length))

        cache_file="$cache_dir/$filename.cache"

        if [[ -f "$cache_file" ]] && [[ "$cache_file" -nt "$file" ]]; then
            cat "$cache_file"
        else
        {
            # Extract and print aliases and functions
            echo -e "\e[38;5;189;48;5;63m $filename$padding\e[0m"
            local prev_line=''
            while IFS= read -r line; do
                if [[ $line =~ ^##[[:space:]] ]]; then
                    echo -e "\e[38;5;38m →${line:2} \e[0m"
                    continue
                elif [[ $line =~ ^[[:space:]]*alias[[:space:]] ]]; then
                    alias_name=$(echo $line | awk -F'=' '{print $1}' | sed 's/alias //')
                    alias_comment=$(echo $line | awk -F'#' '{if($2) print $2}')

                    printf " • \e[32m%-21s\e[0m %s\n" "$alias_name" "$alias_comment"
                elif [[ $line =~ ^[[:space:]]*function ]] || ([[ $line =~ ^[[:alnum:]_]+\(\) ]] && [[ $prev_line != 'private' ]]); then
                    if [[ $line =~ ^[[:space:]]*function ]]; then
                        func_name=$(echo $line | awk '{print $2}' | awk -F'(' '{print $1}')
                    else
                        func_name=$(echo $line | awk -F'(' '{print $1}')
                    fi
                    printf " • \e[32m%-21s\e[0m %s\n" "$func_name" "$prev_line"
                fi
                prev_line=$(echo $line | awk -F'#' '{if($2) print $2}')
            done < "$file"

            echo ""
        } | tee "$cache_file"
        fi
    done
}

alias dh='document_aliases_and_functions "$HOME/.bash.d"' # Shows help for dotfiles

## Kitty terminal
alias ekf='kitty-font-picker' # Edit kitty font (interactive font picker)

## Claude Code
alias cc='claude --dangerously-skip-permissions' # Claude Code without permission prompts
alias ccc='claude --dangerously-skip-permissions --resume' # Claude Code without permissions + resume

## Series Tracker
alias st='~/.bin/series-tracker' # TV series progress tracker

## reMarkable Upload
alias utr='~/.bin/upload-to-remarkable.sh' # Upload files to reMarkable tablet

