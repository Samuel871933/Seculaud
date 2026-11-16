#!/usr/bin/env bash
# PreToolUse Bash : refuse les contournements git de l'équipe (--no-verify, add -f).
# Les commandes qui effacent du travail (reset --hard, push --force, rm -rf…) : voir cc-safety-net dans le README.
source "$(dirname "$0")/conf.sh"; on destructive on || exit 0
cmd=$(grep -oE '"command" *: *"([^"\\]|\\.)*"')
s="(^|[;&|(\`\"' ]|\\\\n)"; a='[^;&|]*'  # ' : commande dans bash -c '…'
why=''
printf '%s' "$cmd" | grep -qE "${s}git ${a}(commit|push|merge|rebase|am)${a}--no-verify|${s}git commit${a} -[a-zA-Z]*n[a-zA-Z]*( |\"|'|$)" && why="--no-verify : les hooks git de l'équipe ne se contournent pas"
printf '%s' "$cmd" | grep -qE "${s}git ${a}add ${a}(-[a-zA-Z]*f[a-zA-Z]*|--force)( |\"|'|$)" && why="git add --force : un fichier ignoré l'est pour une raison (secrets, build)"
[ -n "$why" ] && block "$why. Si c'est voulu, l'utilisateur la lance lui-même (ou désactive la règle destructive)."
exit 0
