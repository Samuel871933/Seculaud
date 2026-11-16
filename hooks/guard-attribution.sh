#!/usr/bin/env bash
# PreToolUse Bash : refuse les commits / PR / tags qui mentionnent Claude comme co-auteur ou générateur.
source "$(dirname "$0")/conf.sh"; on attribution on || exit 0
input=$(cat)
cmd=$(printf '%s' "$input" | grep -oE '"command" *: *"([^"\\]|\\.)*"')
printf '%s' "$cmd" | grep -qE '(git|gh)[^"]*(commit|tag|pr|issue|release)' || exit 0
re='co-authored-by:[^"\\]*(claude|anthropic)|generated (with|by) [^"\\]*claude'
printf '%s' "$cmd" | grep -qiE "$re" && block "pas d'attribution Claude (Co-Authored-By, « Generated with Claude Code ») dans les commits, tags ou PR. Relancer la commande sans ces lignes."
# message dans un fichier : git commit -F f / --file f, gh … --body-file f
cwd=$(printf '%s' "$input" | sed -nE 's/.*"cwd" *: *"([^"]*)".*/\1/p'); cwd=${cwd:-$PWD}
hit=$(printf '%s' "$cmd" | grep -oE "( -F|--file|--body-file|--notes-file)[ =][^ \"';&|]+" | sed -E 's/^ ?-?-?[a-zA-Z-]+[ =]//' | while read -r f; do
  case $f in -) continue ;; /*) ;; ~/*) f="$HOME/${f#\~/}" ;; *) f="$cwd/$f" ;; esac
  grep -qiE "$re" "$f" 2>/dev/null && { echo "$f"; break; }
done)
[ -n "$hit" ] && block "le fichier $hit contient une attribution Claude. La retirer avant de relancer."
exit 0
