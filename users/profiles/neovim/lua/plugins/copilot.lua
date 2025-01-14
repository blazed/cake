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
    -- server = {
    --   type = "binary",
    --   custom_server_filepath = "$COPILOT_LSP_BIN",
    -- }
  }

  cmp.setup {}
end

return M
