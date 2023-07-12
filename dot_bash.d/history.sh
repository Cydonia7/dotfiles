# Most used commands
mus() {
  if [ -z $1 ]; then
    fc -l 1 | grep -v mus | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | grep -v "./" | column -c3 -s " " -t | sort -nr | nl | head -n25
  else
    if [ -z $2 ]; then
      fc -l 1 | grep -v mus | awk '{ if ($2 == "'$1'") {sub(/^$/,"<empty>",$3); if ($3 ~ /\//) {$3="<file>"}; CMD[$3]++; count++; }}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | column -c3 -s " " -t | sort -nr | nl | head -n25
    else
      if [ -z $3 ]; then
        fc -l 1 | grep -v mus | awk '{ if ($2 == "'$1'" && $3 == "'$2'") {sub(/^$/,"<empty>",$4); if ($4 ~ /\//) {$4="<file>"}; CMD[$4]++; count++; }}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | column -c3 -s " " -t | sort -nr | nl | head -n25
      else
        fc -l 1 | grep -v mus | awk '{ if ($2 == "'$1'" && $3 == "'$2'" && $4 == "'$3'") {sub(/^$/,"<empty>",$5); if ($5 ~ /\//) {$5="<file>"}; CMD[$5]++; count++; }}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | column -c3 -s " " -t | sort -nr | nl | head -n25
      fi
    fi
  fi
}
