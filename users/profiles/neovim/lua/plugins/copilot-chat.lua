local M = {}

function M.setup()
  local plugin = require "CopilotChat"

  plugin.setup {
    model = "claude-3.5-sonnet"
  }
end

return M
