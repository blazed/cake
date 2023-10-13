local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

config.font = wezterm.font 'JetBrainsMono Nerd Font Mono'
config.font_size = 10.0
config.color_scheme = 'One Dark (Gogh)'
config.enable_tab_bar = false

config.leader = { key = 'a', mods = 'CTRL' }
config.keys = {
  {
    key = '|',
    mods = 'LEADER|SHIFT',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '-',
    mods = 'LEADER',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'a',
    mods = 'LEADER|CTRL',
    action = act.SendKey { key = 'a', mods = 'CTRL' },
  },
  {
    key = 'k',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    key = 'j',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Down',
  },
  {
    key = 'l',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Right',
  },
  {
    key = 'h',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    key = 'z',
    mods = 'LEADER',
    action = act.TogglePaneZoomState,
  },
}

config.unix_domains = {
  { name = "local-dev" },
  {
    name = "remote-dev",
    proxy_command = wezterm.shell_split('ssh -T -A nicolina wezterm cli proxy')
  },
}

return config
