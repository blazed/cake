local M = {}

function M.setup()
  local plugin = require "Comment"

  plugin.setup {
    padding = true,
    sticky = true,
    toggler = {
      line = "gcc",
      block = "gbc",
    },
    opleader = {
      line = "gc",
      block = "gb",
    },
    mappings = {
      basic = true,
      extra = true,
    },
    pre_hook = nil,
    post_hook = nil,
  }
end

return M
