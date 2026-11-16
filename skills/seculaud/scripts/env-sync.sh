#!/usr/bin/env bash
# Ajoute à .env.local les variables de .env qui y manquent. Ne modifie ni ne supprime l'existant. N'affiche jamais de valeur.
set -eu
d="${1:-.}"; src="$d/.env"; dst="$d/.env.local"
[ -f "$src" ] || { echo "Pas de $src" >&2; exit 1; }
touch "$dst"; chmod 600 "$dst"
key() { sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*/\2/p'; }
have=$(key < "$dst")
added=""
while IFS= read -r line || [ -n "$line" ]; do
  k=$(printf '%s\n' "$line" | key)
  [ -n "$k" ] || continue
  printf '%s\n' "$have" | grep -qxF "$k" && continue
  [ -s "$dst" ] && [ -n "$(tail -c1 "$dst")" ] && echo >> "$dst"
  printf '%s\n' "$line" >> "$dst"
  have="$have"$'\n'"$k"; added="$added $k"
done < "$src"
echo "${added:+Ajoutées dans .env.local :$added}${added:-.env.local déjà complet}"
