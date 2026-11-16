# seculaud

Garde-fous de sécurité pour l'utilisation de Claude Code dans l'équipe.

| Règle | Comment |
|---|---|
| Configs WordPress/PrestaShop illisibles | hook `guard-secrets.sh` : `wp-config.php`, `app/config/parameters.{php,yml}`, `config/settings.inc.php`, `.htpasswd`, `auth.json`. Logs et dumps SQL : bloqués seulement si leur interrupteur est activé |
| `.env.local` illisible | même hook : `.env.local`, `.env.*.local`, `.env.local.php`, globs `.env*` (Read, Grep, Bash, Edit, Write) |
| Identifiants de la machine illisibles | même hook : `~/.ssh/`, `id_rsa`/`id_ed25519`…, `*.pem`, `*.key`, `*.p12`, `~/.aws/`, `.git-credentials`, `.netrc`, `.npmrc`, `.pypirc`, `~/.docker/config.json`, `~/.kube/config`, `~/.config/gcloud/`, `~/.config/gh/`, `~/.gnupg/` |
| Recherches récursives sans fuite | `grep -r` et `rg` (Bash) reçoivent automatiquement `--exclude=…` / `-g '!…'` pour les fichiers ci-dessus ; idem pour l'outil Grep (glob d'exclusion). `xargs`, `find -exec`, `ag`, `ack` : bloqués si le dossier courant contient un fichier sensible. Nécessite `jq` |
| Pas de contournement git | hook `guard-destructive.sh` (Bash) : `--no-verify`, `git commit -n`, `git add -f`, y compris dans `bash -c '…'` |
| Pas de commande qui efface du travail | délégué à [cc-safety-net](https://github.com/kenryu42/claude-code-safety-net) (voir Installation) : `git reset --hard`, `push --force`, `clean -f`, `checkout -- .`, `branch -D`, `stash drop`, `rm -rf`… |
| Pas d'attribution Claude dans les commits, tags et PR | hook `guard-attribution.sh` (refuse `Co-Authored-By: Claude…` et « Generated with Claude Code » dans `git`/`gh`) + réglage `attribution` de `settings.json` (voir Installation) + consigne du skill |
| WebFetch sous contrôle | hook `guard-web.sh` : confirmation demandée pour tout domaine hors `web_allow=` (règle `web`, off par défaut) |
| Avertissement au démarrage | hook `session-check.sh` : `jq` absent, conf illisible |
| Journal d'audit | chaque blocage est noté dans `~/.claude/seculaud.log` (date, dossier, motif) |
| `.env.local` modifiable seulement depuis `.env` | `skills/seculaud/scripts/env-sync.sh` ajoute les variables manquantes, garde celles qui existent, n'affiche que les noms. Seul ce script-là (chemin exact du plugin) est autorisé |

`.env` (le modèle commité) reste lisible.

## Interrupteurs

Chaque règle s'active ou se désactive dans `~/.claude/seculaud.conf` (une ligne `regle=on|off`, fichier absent = défauts) :

| Règle | Défaut | Bloque |
|---|---|---|
| `config` | on | configs WordPress/PrestaShop, `.htpasswd`, `auth.json` |
| `env` | on | `.env.local` et variantes |
| `creds` | on | clés SSH, certificats, identifiants cloud/registres de la machine |
| `attribution` | on | Co-auteur / « Generated with Claude » dans git/gh |
| `destructive` | on | `--no-verify`, `git add -f` |
| `web` | off | WebFetch hors `web_allow` (demande confirmation) |
| `sql` | off | dumps `*.sql*` (hors `modules/*/sql/`), `backups/`, `updraft/`, `ai1wm-backups/` |
| `logs` | off | `*.log`, `var/logs/`, `log/` |

Le plugin `seculaud-band` affiche une ligne au-dessus du prompt (règles actives, règles désactivées). `▸ régler` (ou touche `0`) la déploie : clic ou touches `1` à `8` (après ctrl+x tab) pour basculer une règle.

La liste des domaines autorisés se règle dans le même fichier (séparateur virgule ou espace) ; le band la conserve :

```
web_allow=wordpress.org, php.net, symfony.com, devdocs.prestashop-project.org
```

Le changement s'applique à l'appel d'outil suivant.

## Installation

```
/plugin marketplace add Samuel871933/seculaud
/plugin install seculaud@seculaud
/plugin install seculaud-band@seculaud   # le band d'interrupteurs
```

(ou en local : `/plugin marketplace add /chemin/vers/seculaud`)

### À lancer une fois par poste

Commandes qui effacent du travail (git, `rm -rf`) : [cc-safety-net](https://github.com/kenryu42/claude-code-safety-net) (MIT, Node.js 22+).

```
npx -y cc-safety-net@latest install
npx -y cc-safety-net@latest doctor    # vérifie l'installation
```

Attribution : le hook la bloque déjà, mais c'est `settings.json` qui supprime à la source la ligne `Co-Authored-By` et le pied de PR. Le script fourni s'en charge, et ajoute des règles deny qui doublent les hooks (fusion dans le fichier existant, sauvegarde en `settings.json.bak-seculaud`, relançable sans risque) :

```
bash skills/seculaud/scripts/install-settings.sh             # attribution vide + règles deny Read/Edit/Write
bash skills/seculaud/scripts/install-settings.sh --sandbox   # + sandbox Bash, lecture interdite de ~/.ssh, ~/.aws…
```

Les hooks sont des garde-fous contre l'accident, pas un bac à sable : un script qui lit un fichier sans le nommer (`php -r`, `node -e`) passe. Le sandbox (`sandbox.enabled`, `sandbox.filesystem.denyRead`) est la vraie barrière pour Bash ; sous Linux il demande `bubblewrap` et `socat`. Il change le comportement de Bash (réseau filtré, demandes d'autorisation) : à tester sur un poste avant de le généraliser.

## Tester

```
bash hooks/test-hooks.sh
```
