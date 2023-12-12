local M = {}

function M.setup()
  local plugin = require "nvim-treesitter.configs"

  plugin.setup {
    highlight = {
      enable = true,
      use_languagetree = true,
    },
    indent = {
      enable = true,
    },
  }
end

return M
