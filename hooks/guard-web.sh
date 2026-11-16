#!/usr/bin/env bash
# PreToolUse WebFetch : demande confirmation à l'utilisateur pour un domaine hors de web_allow (contenu externe = risque d'injection de prompt).
source "$(dirname "$0")/conf.sh"; on web off || exit 0
host=$(grep -oE '"url" *: *"[a-z]+://[^/":?#]+' | sed -E 's#.*://##; s/^[^@]*@//' | tr 'A-Z' 'a-z')
[ -z "$host" ] && exit 0
while read -r d; do
  [ -n "$d" ] && { [ "$host" = "$d" ] || [[ $host == *."$d" ]]; } && exit 0
done <<< "$(val web_allow)"
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"seculaud : %s n'"'"'est pas dans web_allow (risque d'"'"'injection de prompt)"}}\n' "$host"
