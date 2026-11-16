# Sourcé par les hooks. Interrupteurs : ~/.claude/seculaud.conf, une ligne cle=on|off (band seculaud ou édition à la main).
conf="${SECULAUD_CONF:-$HOME/.claude/seculaud.conf}"
log="${SECULAUD_LOG:-$HOME/.claude/seculaud.log}"
# on <règle> <défaut on|off>
on() { local v; v=$(grep -sE "^$1=" "$conf" | tail -1 | cut -d= -f2 | tr -d ' \r'); [ "${v:-$2}" = on ]; }
# val <clé> : valeur brute (liste : web_allow), séparateurs virgule/espace → un par ligne
val() { grep -sE "^$1=" "$conf" | tail -1 | cut -d= -f2- | tr ', ' '\n\n' | grep -v '^$'; }
# block <message> : refuse l'appel et le note dans le journal d'audit
block() {
  echo "Bloqué par seculaud : $*" >&2
  printf '%s\t%s\t%s\n' "$(date '+%F %T')" "${PWD}" "$*" >> "$log" 2>/dev/null
  exit 2
}
