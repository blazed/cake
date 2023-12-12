local M = {}

function M.setup()
  local plugin = require "onedark"

  plugin.setup {
    style = "darker"
  }

  plugin.load()
end

return M
