vcenter() {
  local cols=$(tput cols)
  local rows=$(tput lines)

  awk -v cols="$cols" -v rows="$rows" '
        { buf[NR] = $0 }                      # stash lines
        END {
            vpad = int((rows - NR) / 2)       # blank lines above
            for (i = 0; i < vpad; ++i) print ""
            for (i = 1; i <= NR; ++i)
                printf "%*s\n", int((cols + length(buf[i])) / 2), buf[i]
        }'
}

# Actually call the function
vcenter
