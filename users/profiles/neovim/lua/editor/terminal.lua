local M = {}
local m = {}

function M.keymaps()

end

-- Private

function m.paste()
  local content = vim.fn.getreg("*")
  vim.api.nvim_put({ content }, "", true, true)
end

return M
