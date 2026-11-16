import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Rule, Toggles } from '../types'

// Même fichier et mêmes défauts que hooks/conf.sh du plugin seculaud.
const RULES: readonly [Rule, string][] = [
  ['attribution', 'Co-auteur'],
  ['config', 'Configs WP/PS'],
  ['env', '.env.local'],
  ['creds', 'Identifiants'],
  ['bypass', 'Contournement git'],
  ['web', 'Web hors liste'],
  ['sql', 'SQL'],
  ['logs', 'Logs'],
]
const DEFAULTS: Toggles = {
  attribution: true, config: true, env: true, creds: true, bypass: true, web: false, sql: false, logs: false,
}
const toggles = atom({ plugin: 'seculaud-band', key: 'toggles' } as const, DEFAULTS)
const open = atom({ plugin: 'seculaud-band', key: 'open' } as const, false)
const safetyNet = atom({ plugin: 'seculaud-band', key: 'safetyNet' } as const, false)

const parse = (text: string): Toggles => {
  const out = { ...DEFAULTS }
  for (const line of text.split('\n')) {
    const m = /^(\w+)\s*=\s*(on|off)\s*$/.exec(line)
    const k = m?.[1]
    if (k !== undefined && k in out) out[k as Rule] = m?.[2] === "on"
  }
  return out
}
// Remplace la ligne de la règle et garde le reste (web_allow=, commentaires).
const setLine = (text: string, k: Rule, v: boolean) => {
  const line = `${k}=${v ? 'on' : 'off'}`
  const re = new RegExp(`^${k}\\s*=.*$`, 'm')
  if (re.test(text)) return text.replace(re, line)
  const base = text || '# seculaud : on = règle active. Modifiable à la main ou depuis le band.\n'
  return `${base}${base.endsWith('\n') ? '' : '\n'}${line}\n`
}

export const register: Register = on => {
  let path = ''

  on('session.start', async ($, e, next) => {
    path = `${await $.env.get('HOME')}/.claude/seculaud.conf`
    // Fichier absent ou illisible : valeurs par défaut, comme conf.sh.
    const text = await $.fs.read(path).catch(() => '')
    await update($, toggles, () => parse(text))
    // shortcut: cherche « safety-net » dans les réglages et plugins installés ; à revoir si cc-safety-net change sa façon de s'installer.
    const home = `${await $.env.get('HOME')}/.claude`
    const found = await Promise.all(['settings.json', 'plugins/installed_plugins.json'].map(f => $.fs.read(`${home}/${f}`).catch(() => '')))
    await update($, safetyNet, () => found.some(f => f.includes('safety-net')))
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    const t = await read($, toggles)
    const isOpen = await read($, open)
    const sn = await read($, safetyNet)
    const { Box, Button, Text } = $.ui.resolve(e)
    const flip = async (k: Rule) => {
      let saved = t
      await update($, toggles, cur => (saved = { ...cur, [k]: !cur[k] }))
      const text = await $.fs.read(path).catch(() => '')
      await $.fs.write(path, setLine(text, k, saved[k]))
      $.ui.toast(`seculaud : ${k} ${saved[k] ? 'activée' : 'désactivée'}`)
    }
    const off = RULES.filter(([k]) => !t[k]).map(([, label]) => label)

    return (
      <Box flexDirection="column">
        <Box>
          <Text dimColor>🔒 seculaud </Text>
          <Text>{RULES.length - off.length}/{RULES.length} actives</Text>
          {!isOpen && off.length > 0 && <Text dimColor> · off : {off.join(', ')}</Text>}
          <Text dimColor> · </Text><Text>{sn ? '🟢' : '🟠'}</Text><Text dimColor> safety-net{sn ? '' : ' absent'}</Text>
          <Text> </Text>
          <Button hotkey="0" onPress={() => update($, open, o => !o)}>{isOpen ? '▾ réduire' : '▸ régler'}</Button>
        </Box>
        {isOpen && (
          <Box flexWrap="wrap">
            {RULES.map(([k, label], i) => (
              // Pastille hors du Button : la surface VS Code peint en bleu tout le contenu d'un Button.
              <Box key={k}>
                <Text> {t[k] ? '🟢' : '🔴'}</Text>
                <Button hotkey={'12345678'.charAt(i)} onPress={() => flip(k)}>{label}</Button>
              </Box>
            ))}
          </Box>
        )}
      </Box>
    )
  })
}
