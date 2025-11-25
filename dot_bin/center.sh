vcenter() {
  local cols=$(tput cols)
  local rows=$(tput lines)

  awk -v cols="$cols" -v rows="$rows" '
        { buf[NR] = $0 }                      # stash lines
        END {
            vpad = int((rows - NR) / 2)       # blank lines above
            for (i = 0; i < vpad; ++i) print ""
            for (i = 1; i <= NR; ++i) {
                # Remove ANSI escape codes for length calculation
                stripped = buf[i]
                gsub(/\033\[[0-9;]*m/, "", stripped)
                # Calculate padding based on visual length
                pad = int((cols - length(stripped)) / 2)
                # Print padding spaces then the original line
                printf "%*s%s\n", pad, "", buf[i]
            }
        }'
}

# Actually call the function
vcenter
