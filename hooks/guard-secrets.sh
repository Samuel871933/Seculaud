#!/usr/bin/env bash
# PreToolUse : refuse lecture/écriture directe des fichiers sensibles, selon les interrupteurs de conf.sh.
# Recherches récursives (grep -r, rg, outil Grep sur un dossier) : couvertes en bas du fichier.
source "$(dirname "$0")/conf.sh"
input=$(cat)
vals=$(printf '%s' "$input" | grep -oE '"(file_path|notebook_path|path|glob|command)" *: *"([^"\\]|\\.)*"')
# env-sync.sh (celui de ce plugin, chemin exact) est la seule voie d'écriture dans .env.local ; refusé s'il est chaîné à autre chose
es="bash $(cd "$(dirname "$0")/.." && pwd)/skills/seculaud/scripts/env-sync.sh"
c=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
case $c in "$es"|"$es "*) [[ ${c#"$es"} != *[\;\&\|\`\$\<\>\\$'\n']* ]] && exit 0 ;; esac
pat='|seculaud\.(conf|log)'  # toujours : Claude ne doit pas changer ses propres interrupteurs
on config on && pat="$pat|wp-config\.php|app/config/parameters\.(php|yml)|config/settings\.inc\.php|\.htpasswd|auth\.json"
on env on    && pat="$pat|\.env(\.[A-Za-z0-9_-]+)?\.local(\.php)?|\.env[^ \"/]*[*?]"
on creds on  && pat="$pat|\.ssh/|id_(rsa|dsa|ecdsa|ed25519)\b|[A-Za-z0-9_-][A-Za-z0-9_.-]*\.(pem|key|p12|pfx|jks)\b|\.aws/|\.git-credentials|\.netrc|\.npmrc|\.pypirc|\.docker/config\.json|\.kube/config|\.config/(gcloud|gh)/|\.gnupg/|\.password-store/"
on logs off  && pat="$pat|var/logs?/|log/|[^ \"/]+\.log\b"
on sql off   && pat="$pat|wp-content/(updraft|ai1wm-backups)/|(admin[^/ \"]*/)?backups?/"
hit=''
[ -n "$pat" ] && hit=$(printf '%s\n' "$vals" | grep -oE "(^|[/ \"'=])(${pat#|})")
[ -z "$hit" ] && on sql off && hit=$(printf '%s\n' "$vals" | grep -E '\.sql(\.gz|\.bz2|\.zip)?\b' | grep -vE 'modules/[^ "]*\.sql\b' | grep -oE '[^ "/]*\.sql[^ "]*')
if [ -n "$hit" ]; then
  f=$(echo "$hit" | head -1 | tr -d ' "'"'"'=')
  case "$f" in
    *.env*) why="lecture/écriture directe interdite. Pour compléter .env.local depuis .env : bash <skill seculaud>/scripts/env-sync.sh <dossier>" ;;
    *) why="fichier sensible (règle active dans ~/.claude/seculaud.conf). Demander à l'utilisateur de désactiver la règle s'il le souhaite." ;;
  esac
  block "$f — $why"
fi

# Recherche récursive : aucun fichier nommé dans l'appel, mais elle lirait les fichiers sensibles du dossier.
# shortcut: logs/sql non couverts ici ; Bash : cherche sous cwd seulement (cd ailleurs && grep -r passe), find limité à 3 s / 6 niveaux.
names=()
on config on && names+=(wp-config.php '**/app/config/parameters.php' '**/app/config/parameters.yml' '**/config/settings.inc.php' .htpasswd auth.json)
on env on    && names+=(.env.local '.env.*.local' .env.local.php)
on creds on  && names+=('*.pem' '*.key' '*.p12' '*.pfx' id_rsa id_dsa id_ecdsa id_ed25519 .git-credentials .netrc .npmrc .pypirc)
[ ${#names[@]} = 0 ] && exit 0
jv() { printf '%s' "$input" | sed -nE 's/.*"'"$1"'" *: *"(([^"\\]|\\.)*)".*/\1/p' | head -1; }
sensitive_in() { # premier fichier sensible sous $1
  local a=() n
  for n in "${names[@]}"; do case $n in '**/'*) a+=(-o -path "*/${n#\*\*/}") ;; *) a+=(-o -name "$n") ;; esac; done
  timeout 3 find "$1" -maxdepth 6 \( -name node_modules -o -name vendor -o -name .git \) -prune -o \( "${a[@]:1}" \) -print -quit 2>/dev/null
}
tool=$(jv tool_name); cwd=$(jv cwd); cwd=${cwd:-$PWD}
case $tool in
  Grep)
    dir=$(jv path); dir=${dir:-$cwd}; [[ $dir = /* ]] || dir="$cwd/$dir"
    [ -d "$dir" ] || exit 0
    glob=$(jv glob)
    if [ -z "$glob" ] && command -v jq >/dev/null; then # exclusion ajoutée au glob de ripgrep
      ex=$(IFS=,; echo "!{${names[*]}}")
      printf '%s' "$input" | jq -c --arg g "$ex" '{hookSpecificOutput:{hookEventName:"PreToolUse",updatedInput:(.tool_input+{glob:$g})}}'
      exit 0
    fi
    ext=$(printf '%s' "$glob" | sed -nE 's#^[*/]*\.([A-Za-z0-9]+)$#\1#p')
    [ -n "$ext" ] && ! printf '%s' "$ext" | grep -qiE '^(php|yml|json|local|pem|key|p12|pfx)$' && exit 0
    f=$(sensitive_in "$dir"); [ -z "$f" ] && exit 0
    block "cette recherche lirait ${f#"$dir"/}. Relancer Grep sans glob (filtrer avec type, ex. type=php) : les fichiers sensibles sont alors exclus automatiquement." ;;
  Bash)
    cmd=$(jv command); d='(^|[;&|( ]|\\n)'
    printf '%s' "$cmd" | grep -qE "$d((e|f)?grep [^;&|]*(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive|--dereference-recursive|--directories[= ]recurse)( |$)|rg( |$))" && command -v jq >/dev/null && {
      # grep -r / rg : on ajoute les exclusions à la commande plutôt que de bloquer
      ge=''; re=''; for n in "${names[@]}"; do ge+=" --exclude='${n##*/}'"; re+=" -g '!$n'"; done
      printf '%s' "$input" | jq -c --arg ge "$ge" --arg re "$re" '.tool_input | .command |= (
        gsub("(?<p>^|[;&|(\n ])(?<!git )(?<c>[ef]?grep) "; "\(.p)\(.c)\($ge) ") | gsub("(?<p>^|[;&|(\n ])rg "; "\(.p)rg\($re) "))
        | {hookSpecificOutput:{hookEventName:"PreToolUse",updatedInput:.}}'
      exit 0; }
    # ag/ack/xargs/find -exec (ou jq absent) : pas d'exclusion possible, blocage si le dossier contient un fichier sensible
    printf '%s' "$cmd" | grep -qE "$d((e|f)?grep [^;&|]*(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)( |$)|(rg|ag|ack|ugrep)( |$)|(xargs|find [^;&|]*-exec)[^;&|]*(grep|cat|head|tail|less|more|strings|awk|sed))" || exit 0
    f=$(sensitive_in "$cwd"); [ -z "$f" ] && exit 0
    block "lecture en masse d'un dossier contenant ${f#"$cwd"/}. Utiliser grep -r ou rg (les fichiers sensibles y sont exclus automatiquement)." ;;
esac
exit 0
