export type Rule = 'attribution' | 'config' | 'env' | 'sql' | 'logs' | 'creds' | 'destructive' | 'web'
export type Toggles = Record<Rule, boolean>

declare module 'claude-code' {
  interface PluginState {
    'seculaud-band': { toggles: Toggles; open: boolean }
  }
}
