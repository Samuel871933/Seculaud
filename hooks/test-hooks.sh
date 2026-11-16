#!/usr/bin/env bash
# Auto-test : bash hooks/test-hooks.sh
h="$(cd "$(dirname "$0")" && pwd)"; fail=0
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
export SECULAUD_CONF="$t/conf"  # absent = valeurs par défaut
export SECULAUD_LOG="$t/log"
check() { # attendu(0|2) hook json
  printf '%s' "$3" | bash "$h/$2" 2>/dev/null; r=$?
  [ "$r" = "$1" ] || { echo "ÉCHEC ($r au lieu de $1) : $2 $3"; fail=1; }
}
g=guard-secrets.sh
check 2 $g '{"tool_input":{"file_path":"/site/wp-config.php"}}'
check 2 $g '{"tool_input":{"command":"cat wp-config.php"}}'
check 2 $g '{"tool_input":{"file_path":"/shop/app/config/parameters.php"}}'
check 2 $g '{"tool_input":{"file_path":"/shop/config/settings.inc.php"}}'
check 2 $g '{"tool_input":{"file_path":"/app/.env.local"}}'
check 2 $g '{"tool_input":{"file_path":"/app/.env.prod.local"}}'
check 2 $g '{"tool_input":{"command":"cat .env*"}}'
check 2 $g '{"tool_input":{"command":"echo A=1 >> .env.local"}}'
check 2 $g '{"tool_input":{"file_path":"/app/.env.local","content":"A=1"}}'
es="bash $(cd "$h/.." && pwd)/skills/seculaud/scripts/env-sync.sh"
check 0 $g '{"tool_input":{"command":"'"$es"' /app"}}'
check 2 $g '{"tool_input":{"command":"'"$es"' . ; cat .env.local"}}'
check 2 $g '{"tool_input":{"command":"'"$es"' .\ncat .env.local"}}'
check 2 $g '{"tool_input":{"command":"bash /tmp/scripts/env-sync.sh . .env.local"}}'  # faux env-sync écrit ailleurs
check 0 $g '{"tool_input":{"file_path":"/app/.env"}}'
check 2 $g '{"tool_input":{"command":"echo sql=off > ~/.claude/seculaud.conf"}}'
check 0 $g '{"tool_input":{"file_path":"/site/wp-content/debug.log"}}'
check 0 $g '{"tool_input":{"command":"tail -n 200 var/logs/prod.log"}}'
check 0 $g '{"tool_input":{"command":"zcat backups/dump.sql.gz | head"}}'
check 0 $g '{"tool_input":{"file_path":"/app/.env.example"}}'
check 0 $g '{"tool_input":{"file_path":"/site/wp-config-sample.php"}}'
check 0 $g '{"tool_input":{"file_path":"/shop/modules/ps_blog/blog/x.php"}}'
check 0 $g '{"tool_input":{"file_path":"/shop/modules/abcfaq/sql/install.sql"}}'
# interrupteurs
printf 'sql=on\nlogs=on\nenv=off\n' > "$SECULAUD_CONF"
check 2 $g '{"tool_input":{"command":"zcat backups/dump.sql.gz | head"}}'
check 2 $g '{"tool_input":{"file_path":"/site/wp-content/debug.log"}}'
check 2 $g '{"tool_input":{"command":"tail -n 200 var/logs/prod.log"}}'
check 0 $g '{"tool_input":{"file_path":"/shop/modules/abcfaq/sql/install.sql"}}'
check 0 $g '{"tool_input":{"file_path":"/app/.env.local"}}'
check 2 $g '{"tool_input":{"file_path":"/site/wp-config.php"}}'
rm "$SECULAUD_CONF"
a=guard-attribution.sh
check 2 $a '{"tool_input":{"command":"git commit -m \"fix\n\nCo-Authored-By: Claude Opus <noreply@anthropic.com>\""}}'
check 2 $a '{"tool_input":{"command":"gh pr create --body \"x\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\""}}'
check 0 $a '{"tool_input":{"command":"git commit -m \"fix\n\nCo-Authored-By: Alice <a@b.c>\""}}'
check 0 $a '{"tool_input":{"command":"grep -r Co-Authored-By: Claude docs/"}}'
printf 'fix\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' > "$t/msg"; printf 'fix\n' > "$t/ok"
check 2 $a '{"cwd":"'"$t"'","tool_input":{"command":"git commit -F msg"}}'
check 2 $a '{"tool_input":{"command":"gh pr create --body-file '"$t"'/msg"}}'
check 0 $a '{"tool_input":{"command":"git commit -F '"$t"'/ok"}}'
printf 'attribution=off\n' > "$SECULAUD_CONF"; check 0 $a '{"tool_input":{"command":"git commit -m \"x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\""}}'; rm "$SECULAUD_CONF"
# env-sync : garde l'existant, ajoute le manquant, n'affiche pas de valeur
printf 'A=1\nexport B=2\n# C=3\nD=secret_defaut\n' > "$t/.env"; printf 'A=deja\nX=9' > "$t/.env.local"
out=$(bash "$h/../skills/seculaud/scripts/env-sync.sh" "$t")
[ "$(cat "$t/.env.local")" = "$(printf 'A=deja\nX=9\nexport B=2\nD=secret_defaut')" ] || { echo "ÉCHEC env-sync contenu"; fail=1; }
case "$out" in *secret*|*deja*) echo "ÉCHEC env-sync affiche une valeur"; fail=1;; esac
[ "$(bash "$h/../skills/seculaud/scripts/env-sync.sh" "$t")" = ".env.local déjà complet" ] || { echo "ÉCHEC env-sync idempotent"; fail=1; }
# identifiants machine
check 2 $g '{"tool_input":{"command":"cat ~/.ssh/id_ed25519"}}'
check 2 $g '{"tool_input":{"file_path":"/home/u/.aws/credentials"}}'
check 2 $g '{"tool_input":{"file_path":"/app/config/jwt/private.pem"}}'
check 2 $g '{"tool_input":{"command":"cat ~/.git-credentials"}}'
check 0 $g '{"tool_input":{"command":"jq .config.key data.json"}}'
check 0 $g '{"tool_input":{"file_path":"/app/src/keyboard.js"}}'
# recherche récursive : $t/site contient une config sensible, $t/clean non
mkdir -p "$t/site/app/config" "$t/clean"; : > "$t/site/wp-config.php"; : > "$t/clean/a.php"
out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"cd /x && grep -rn DB_ . | git grep -n y"}}' | bash "$h/$g")
case "$out" in *'"command":"cd /x && grep --exclude='*'-rn DB_ . | git grep -n y"'*) ;; *) echo "ÉCHEC grep -r exclusion : $out"; fail=1;; esac
out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"rg DB_"}}' | bash "$h/$g")
case "$out" in *'"command":"rg -g '*'!.env.local'*' DB_"'*) ;; *) echo "ÉCHEC rg exclusion : $out"; fail=1;; esac
check 2 $g '{"tool_name":"Bash","cwd":"'"$t/site"'","tool_input":{"command":"find . -name \"*.php\" | xargs grep DB_"}}'
check 0 $g '{"tool_name":"Bash","cwd":"'"$t/clean"'","tool_input":{"command":"find . | xargs grep DB_"}}'
check 0 $g '{"tool_name":"Bash","cwd":"'"$t/site"'","tool_input":{"command":"grep -n DB_ a.php"}}'
check 2 $g '{"tool_name":"Grep","cwd":"'"$t/site"'","tool_input":{"pattern":"DB_","glob":"*.php"}}'
check 0 $g '{"tool_name":"Grep","cwd":"'"$t/site"'","tool_input":{"pattern":"DB_","glob":"*.js"}}'
out=$(printf '%s' '{"tool_name":"Grep","cwd":"'"$t/site"'","tool_input":{"pattern":"DB_","type":"php"}}' | bash "$h/$g")
case "$out" in *'"updatedInput"'*'"glob":"!{wp-config.php,'*'"type":"php"'*|*'"updatedInput"'*'"type":"php"'*'"glob":"!{wp-config.php,'*) ;; *) echo "ÉCHEC Grep exclusion : $out"; fail=1;; esac
# commandes destructrices / contournements git
k=guard-bypass.sh
check 2 $k '{"tool_input":{"command":"git commit --no-verify -m x"}}'
check 2 $k '{"tool_input":{"command":"git commit -nm x"}}'
check 2 $k '{"tool_input":{"command":"git push --no-verify"}}'
check 2 $k '{"tool_input":{"command":"git add -f .env.prod"}}'
check 2 $k '{"tool_input":{"command":"bash -c '"'"'git add -f secret'"'"'"}}'
check 0 $k '{"tool_input":{"command":"git add -A && git commit -m \"fix\""}}'
check 0 $k '{"tool_input":{"command":"git push -f"}}'  # laissé à cc-safety-net
grep -q "no-verify" "$SECULAUD_LOG" || { echo "ÉCHEC journal d'audit vide"; fail=1; }
printf 'creds=off\n' > "$SECULAUD_CONF"; check 0 $g '{"tool_input":{"command":"cat ~/.ssh/id_ed25519"}}'; rm "$SECULAUD_CONF"
printf 'bypass=off\n' > "$SECULAUD_CONF"; check 0 $k '{"tool_input":{"command":"git commit --no-verify -m x"}}'; rm "$SECULAUD_CONF"
# WebFetch (règle off par défaut)
[ -z "$(printf '%s' '{"tool_input":{"url":"https://evil.io/x"}}' | bash "$h/guard-web.sh")" ] || { echo "ÉCHEC web : actif par défaut"; fail=1; }
printf 'web=on\nweb_allow=wordpress.org, php.net\n' > "$SECULAUD_CONF"
case "$(printf '%s' '{"tool_input":{"url":"https://evil.io/x"}}' | bash "$h/guard-web.sh")" in *'"ask"'*evil.io*) ;; *) echo "ÉCHEC web : evil.io pas demandé"; fail=1;; esac
[ -z "$(printf '%s' '{"tool_input":{"url":"https://developer.wordpress.org/x"}}' | bash "$h/guard-web.sh")" ] || { echo "ÉCHEC web : sous-domaine autorisé refusé"; fail=1; }
[ -n "$(printf '%s' '{"tool_input":{"url":"https://notwordpress.org/x"}}' | bash "$h/guard-web.sh")" ] || { echo "ÉCHEC web : notwordpress.org autorisé"; fail=1; }
[ $fail = 0 ] && echo "hooks OK"; exit $fail
