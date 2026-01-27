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

## Rep Challenge Tracker
alias rc='~/.bin/rep-challenge' # Rep challenge progress tracker

## reMarkable Upload
alias utr='~/.bin/upload-to-remarkable.sh' # Upload files to reMarkable tablet

## Next Train
alias nt='~/Projects/cydo/tools/next-train/next-train.sh' # Next metro departures

## Tennis Court Update
alias ute='~/Projects/cydo/tools/tcg-tennis/.venv/bin/python ~/Projects/cydo/tools/tcg-tennis/update_class_event.py' # Update tennis event with court

## Minecraft
mcplayers() {
    local host="51.79.78.207"
    local port="25565"
    local address="${host}:${port}"

    python3 - "$host" "$port" <<'PY'
import json
import socket
import struct
import sys

host = sys.argv[1]
port = int(sys.argv[2])
address = f"{host}:{port}"

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(3.0)


def pack_varint(value: int) -> bytes:
    out = b""
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            out += struct.pack("B", byte | 0x80)
        else:
            out += struct.pack("B", byte)
            return out


def unpack_varint(stream) -> int:
    num = 0
    for i in range(5):
        byte = stream.recv(1)
        if not byte:
            raise ConnectionError("Unexpected EOF")
        value = byte[0]
        num |= (value & 0x7F) << (7 * i)
        if not (value & 0x80):
            return num
    raise ValueError("Varint too long")


try:
    sock.connect((host, port))

    protocol = 754
    host_bytes = host.encode("utf-8")
    handshake = (
        pack_varint(0x00)
        + pack_varint(protocol)
        + pack_varint(len(host_bytes))
        + host_bytes
        + struct.pack(">H", port)
        + pack_varint(1)
    )
    sock.sendall(pack_varint(len(handshake)) + handshake)

    request = pack_varint(0x00)
    sock.sendall(pack_varint(len(request)) + request)

    length = unpack_varint(sock)
    packet_id = unpack_varint(sock)
    if packet_id != 0x00:
        raise ValueError("Invalid status packet")

    json_length = unpack_varint(sock)
    payload = sock.recv(json_length)
    data = json.loads(payload.decode("utf-8"))
except socket.timeout:
    print("Status query timed out")
    sys.exit(1)
except (OSError, ValueError, json.JSONDecodeError) as exc:
    print(f"Status query failed: {exc}")
    sys.exit(1)
finally:
    sock.close()

players = data.get("players", {})
online = players.get("online", 0)
list_names = [entry.get("name") for entry in players.get("sample", []) if entry.get("name")]

if list_names:
    print(f"{address} online: {online} -> {', '.join(list_names)}")
elif online:
    print(f"{address} online: {online} (names unavailable)")
else:
    print(f"{address} online: {online}")
PY
}


alias mc='mcplayers' # Minecraft server player count

