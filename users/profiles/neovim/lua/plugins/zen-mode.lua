local M = {}
local m = {}

function M.setup()
  local plugin = require "zen-mode"

  plugin.setup {
    window = {
      backdrop = 1,
      width = 118,
    },
  }
end

function M.keymaps()
  K.map { "<M-m>", "Toggle zen mode", m.toggle, mode = { "n", "i", "v" } }
end

function M.ensure_deactivated()
  if m.is_active() then
    m.deactivate()
    return true
  else
    return false
  end
end

-- Private

function m.toggle()
  if m.is_active() then
    m.deactivate()
  else
    m.activate()
  end
end

function m.activate()
  local plugin = require "zen-mode"

  local zen_buf = vim.api.nvim_get_current_buf()

  plugin.toggle()

  local current_buf = vim.api.nvim_get_current_buf()

  if current_buf == zen_buf then
    return
  end

  vim.api.nvim_set_current_buf(zen_buf)
end

function m.is_active()
  local zenmode = require "zen-mode.view"

  local is_open = zenmode.is_open()

  if is_open == nil then
    return false
  else
    return is_open
  end
end

return M
