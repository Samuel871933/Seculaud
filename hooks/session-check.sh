#!/usr/bin/env bash
# SessionStart : prévient l'utilisateur quand une protection est affaiblie sans bruit (jq absent, conf illisible).
source "$(dirname "$0")/conf.sh"
w=()
command -v jq >/dev/null || w+=("jq absent : grep -r/rg ne sont plus filtrés automatiquement et env-sync.sh est refusé (sudo apt install jq)")
[ -e "$conf" ] && [ ! -r "$conf" ] && w+=("$conf illisible : valeurs par défaut appliquées")
[ ${#w[@]} = 0 ] && exit 0
msg="seculaud : $(IFS='|'; echo "${w[*]}" | sed 's/|/ ; /g')"
printf '{"systemMessage":"%s"}\n' "$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')"
