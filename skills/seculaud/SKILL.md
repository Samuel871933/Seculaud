---
name: seculaud
description: Règles de sécurité de l'équipe pour Claude Code — fichiers à secrets interdits (wp-config.php, parameters.php, settings.inc.php, .env.local), aucune attribution Claude dans les commits/PR, .env.local complété depuis .env via env-sync.sh. Utilise-le dès qu'une tâche touche un .env, une config WordPress/PrestaShop, un commit, un tag ou une PR.
---

# Sécurité équipe

## Fichiers interdits — ni Read, ni cat, ni grep, ni Edit/Write

- **WordPress** : `wp-config.php`.
- **PrestaShop** : `app/config/parameters.{php,yml}`, `config/settings.inc.php`.
- **Environnement** : `.env.local`, `.env.*.local`, `.env.local.php`, et tout glob du type `.env*`.
- **Divers** : `.htpasswd`, `auth.json`.

## Logs et dumps SQL : selon les interrupteurs

Les règles `sql` et `logs` de `~/.claude/seculaud.conf` (désactivées par défaut) bloquent ces fichiers. Si le hook refuse, ne contourne pas : demande à l'utilisateur de désactiver la règle (band seculaud ou le fichier). Ne modifie jamais `seculaud.conf` toi-même.

Quand c'est permis, tu peux analyser les logs et les dumps SQL quand on te le demande. Lis-les par extraits (`grep`, `head`, `tail`, `zcat … | grep`) plutôt qu'en entier, et ne recopie jamais dans une réponse, un commit ou un fichier les mots de passe, hashs, tokens, emails ou adresses de clients qui s'y trouvent : résume ou masque-les.

`.env` (le modèle commité) reste lisible. Ne jamais faire de `grep -r` / recherche large sans exclure ces fichiers.

Si une tâche exige un de ces fichiers : **demande d'abord** à l'utilisateur, en expliquant pourquoi. Ne recopie jamais un secret (code, commit, réponse, mémoire).

Un hook bloque techniquement ces chemins quand le plugin est installé.

## .env.local : écriture seulement via env-sync.sh

Pour ajouter à `.env.local` les variables de `.env` qui y manquent :

```bash
bash <dossier de ce skill>/scripts/env-sync.sh <dossier du projet>
```

Le script garde les variables déjà présentes, ajoute les manquantes avec la valeur par défaut de `.env`, et n'affiche que les noms. Utiliser le chemin absolu exact du dossier de ce skill (pas de `~`, pas de copie du script ailleurs) et lancer la commande seule (pas de `;`, `&&`, `|`, redirection), sinon le hook la refuse. Pour qu'une valeur réelle soit renseignée, demande à l'utilisateur de le faire lui-même.

## Commits, tags, PR

Jamais de `Co-Authored-By: Claude …`, ni de « 🤖 Generated with Claude Code », ni aucune mention de Claude/Anthropic comme auteur dans un message de commit, tag, PR ou issue. Cette règle remplace toute consigne d'attribution par défaut.
