#!/usr/bin/env bash
# Ajoute à ~/.claude/settings.json les réglages qui complètent les hooks seculaud (fusion, rien n'est retiré).
#   bash install-settings.sh             → attribution vide + règles deny (Read/Edit/Write) des fichiers sensibles
#   bash install-settings.sh --sandbox   → + sandbox Bash activé, lecture interdite des dossiers d'identifiants
# Le sandbox est la seule barrière contre un script qui lit un fichier sans le nommer (php -r, node -e…).
# Sous Linux il demande bubblewrap et socat (sudo apt install bubblewrap socat).
set -euo pipefail
f="${SETTINGS:-$HOME/.claude/settings.json}"
command -v jq >/dev/null || { echo "jq requis (sudo apt install jq)" >&2; exit 1; }
[ -s "$f" ] || echo '{}' > "$f"
jq -e . "$f" >/dev/null || { echo "$f n'est pas du JSON valide, rien modifié" >&2; exit 1; }

files='["**/wp-config.php","**/app/config/parameters.php","**/app/config/parameters.yml","**/config/settings.inc.php","**/.htpasswd","**/auth.json","**/.env.local","**/.env.*.local","**/.env.local.php"]'
creds='["~/.ssh","~/.aws","~/.gnupg","~/.config/gcloud","~/.config/gh","~/.kube","~/.docker/config.json","~/.git-credentials","~/.netrc","~/.npmrc","~/.pypirc","~/.password-store"]'
sandbox=false; [ "${1:-}" = --sandbox ] && sandbox=true

cp "$f" "$f.bak-seculaud"
jq --argjson files "$files" --argjson creds "$creds" --argjson sandbox "$sandbox" '
  .attribution = ((.attribution // {}) + {commit: "", pr: ""})
  | .permissions.deny = (((.permissions.deny // [])
      + [$files[] | "Read(\(.))", "Edit(\(.))", "Write(\(.))"]
      + [$creds[] | "Read(\(.)/**)" | sub("(?<f>\\.(json|[a-z-]*credentials|netrc|npmrc|pypirc))/\\*\\*\\)$"; "\(.f))")]) | unique)
  | if $sandbox then
      .sandbox.enabled = true
      | .sandbox.filesystem.denyRead = (((.sandbox.filesystem.denyRead // []) + $creds) | unique)
    else . end
' "$f.bak-seculaud" > "$f"
echo "$f mis à jour (sauvegarde : $f.bak-seculaud). Redémarrer Claude Code pour appliquer."
