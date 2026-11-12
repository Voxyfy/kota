#!/bin/sh
# Claude Code durum satırı betiği: girdideki limitleri ~/.claude/kota/claude.json'a yazar.
# Çıktı vermez, yani durum satırı boş kalır. Limit verisi yoksa eski dosyaya dokunmaz.
dir="$HOME/.claude/kota"
mkdir -p "$dir"
tmp="$dir/claude.json.$$"
if jq -ce '.rate_limits | select(.five_hour or .seven_day)
    | [(.five_hour | select(.) | {label: "5 saatlik"} + .),
       (.seven_day | select(.) | {label: "Haftalık"} + .)]' > "$tmp" 2>/dev/null; then
  mv "$tmp" "$dir/claude.json"
else
  rm -f "$tmp"
fi
exit 0
