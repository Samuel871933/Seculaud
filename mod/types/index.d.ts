export type Rule = 'attribution' | 'config' | 'env' | 'sql' | 'logs' | 'creds' | 'bypass' | 'web'
export type Toggles = Record<Rule, boolean>

declare module 'claude-code' {
  interface PluginState {
    'seculaud-band': { toggles: Toggles; open: boolean; safetyNet: boolean }
  }
}
