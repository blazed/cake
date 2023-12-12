local M = {}
local m = {}

function M.setup()
  local plugin = require "lsp_lines"

  vim.diagnostic.config({ virtual_lines = false })

  plugin.setup()
end

function M.keymaps()
  K.map { "<C-l>", "LSP: Toggle diagnostic lines", m.toggle, mode = "n" }
end

-- Private

function m.toggle()
  local plugin = require "lsp_lines"
  local visible = plugin.toggle()
  vim.diagnostic.config({ virtual_text = not visible })
end

return M
