local M = {}

function M.setup()
  local plugin = require "null-ls"
  local utils = require "null-ls.utils"

  plugin.setup {
    sources = {
      plugin.builtins.diagnostics.eslint_d,
      plugin.builtins.diagnostics.shellcheck,
      plugin.builtins.diagnostics.statix,
      plugin.builtins.code_actions.shellcheck,
      plugin.builtins.code_actions.statix,
      plugin.builtins.formatting.prettier,
      plugin.builtins.formatting.eslint_d,
      -- function()
      --   local bin = "node_modules/.bin/prettier"
      --   local cond = utils.make_conditional_utils()
      --   return plugin.builtins.formatting.prettier.with({
      --     command = cond.root_has_file(bin) and bin or "prettier",
      --   })
      -- end,
    }
  }
end

return M
