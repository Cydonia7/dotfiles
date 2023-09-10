#!/bin/bash

#private
document_aliases_and_functions() {
    if [[ -z "$1" ]]
    then
        echo "Directory not provided"
        return 1
    fi

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

        echo -e "\e[38;5;189;48;5;63m $filename$padding\e[0m"

        # Extract and print aliases and functions
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
    done
}

alias dh='document_aliases_and_functions "$HOME/.bash.d"' # Shows help for dotfiles

