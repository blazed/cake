local wezterm = require "wezterm"
local mux = wezterm.mux
local act = wezterm.action
local config = wezterm.config_builder()

wezterm.on("NewProjectWindow", function(_, pane)
  local domain = pane:get_domain_name()
  local cwd = pane:get_current_working_dir()

  return mux.spawn_window({domain = { DomainName = domain }, cwd = cwd.file_path })
end)

wezterm.on("NewProjectTab", function(window, pane)
  local domain = pane:get_domain_name()
  local cwd = pane:get_current_working_dir()

  return window:mux_window():spawn_tab({ domain = { DomainName = domain }, cwd = cwd.file_path })
end)

local solid_right_arrow = wezterm.nerdfonts.pl_left_hard_divider

local function tab_title(tab_info)
  local title = tab_info.tab_title
  if title and #title > 0 then
    return title
  end
  return tab_info.active_pane.title
end

wezterm.on(
  "format-tab-title",
  function(tab, tabs, _, _, _, _)
    local title = tab_title(tab)
    local first = (tab.tab_index == 0)
    local last = (tab.tab_index == (#tabs -1))
    local tab_bg = "#22336e"
    local active_bg_color = "#51576d"
    local inactive_bg_color = "#0b0022"
    local active_fg_color = "#a9a6ac"
    local inactive_fg_color = "#66646c"

    local function get_color()
      if last then
        return tab_bg
      else
        return inactive_bg_color
      end
    end

    if tab.is_active then
      if first then
        return {
          { Background = { Color = active_bg_color } },
          { Foreground = { Color = active_bg_color } },
          { Text = " " },
          { Background = { Color = active_bg_color } },
          { Foreground = { Color = active_fg_color } },
          { Text = (tostring(tab.tab_index + 1)) .. ": " .. title .. " " },
          { Background = { Color = get_color() } },
          { Foreground = { Color = active_bg_color } },
          { Text = solid_right_arrow },
        }
      else
        return {
          { Background = { Color = active_bg_color } },
          { Foreground = { Color = inactive_bg_color } },
          { Text = solid_right_arrow },
          { Background = { Color = active_bg_color } },
          { Foreground = { Color = active_fg_color } },
          { Text = (tostring(tab.tab_index + 1)) .. ": " .. title .. " " },
          { Background = { Color = get_color() } },
          { Foreground = { Color = active_bg_color } },
          { Text = solid_right_arrow },
        }
      end
    else
      if first then
        return {
          { Background = { Color = inactive_bg_color } },
          { Foreground = { Color = inactive_bg_color } },
          { Text = " " },
          { Background = { Color = inactive_bg_color } },
          { Foreground = { Color = inactive_fg_color } },
          { Text = (tostring(tab.tab_index + 1)) .. ": " .. title .. " " },
        }
      else
        return {
          { Background = { Color = inactive_bg_color } },
          { Foreground = { Color = inactive_bg_color } },
          { Text = " " },
          { Background = { Color = inactive_bg_color } },
          { Foreground = { Color = inactive_fg_color } },
          { Text = (tostring(tab.tab_index + 1)) .. ": " .. title .. " " },
          { Background = { Color = get_color() } },
          { Foreground = { Color = active_bg_color } },
          { Text = solid_right_arrow },
        }
      end
    end
  end
)

config.enable_wayland = true
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.show_tabs_in_tab_bar = true
config.show_new_tab_button_in_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true
config.font = wezterm.font "JetBrainsMono Nerd Font"
config.font_size = 10
config.color_scheme = "One Dark (Gogh)"
config.window_background_opacity = 0.90
config.switch_to_last_active_tab_when_closing_tab = true

config.leader = { key = "a", mods = "CTRL" }
config.keys = {
  { key = "a", mods = "LEADER|CTRL", action = act.SendKey { key = "a", mods = "CTRL" } },
  { key = "l", mods = "LEADER|SHIFT", action = act.SplitPane { direction = "Right", size = { Percent = 50 } } },
  { key = "h", mods = "LEADER|SHIFT", action = act.SplitPane { direction = "Left", size = { Percent = 50 } } },
  { key = "k", mods = "LEADER|SHIFT", action = act.SplitPane { direction = "Up", size = { Percent = 50 } } },
  { key = "j", mods = "LEADER|SHIFT", action = act.SplitPane { direction = "Down", size = { Percent = 50 } } },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection "Right" },
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection "Left" },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection "Up" },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection "Down" },
  { key = "q", mods = "LEADER|SHIFT", action = act.CloseCurrentPane { confirm = true } },
  { key = "n", mods = "LEADER|CTRL", action = act.EmitEvent "NewProjectWindow" },
  { key = "t", mods = "LEADER|CTRL", action = act.EmitEvent "NewProjectTab" },
  { key = "f", mods = "LEADER|CTRL", action = act.ShowLauncherArgs { flags = "FUZZY|WORKSPACES" } },
}

return config
