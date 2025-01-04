local M = {}

function M.setup()
  local plugin = require "copilot"
  local cmp = require "copilot_cmp"

  plugin.setup {
    suggestion = {
      enabled = false
    },
    panel = {
      enabled = false
    },
  }

  cmp.setup {}
end

return M
