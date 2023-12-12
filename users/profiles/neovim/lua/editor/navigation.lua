local M = {}
local m = {}

function M.keymaps()
end

-- Private

function m.scroll_horizontal(direction)
  if direction == "left" then
    vim.cmd "normal! 5zh"
  elseif direction == "right" then
    vim.cmd "normal! 5zl"
  else
    vim.api.nvim_err_writeln "Unexpected scroll direction"
  end
end

function m.scroll_vertical(direction)
  local windows = require "editor.windows"
  local keys = require "editor.keys"
  local noice = require "plugins.noice"

  if noice.scroll_lsp_doc(direction) then
    return
  elseif windows.is_window_floating(vim.api.nvim_get_current_win()) then
    local keymap

    if direction == "up" then
      keymap = "<C-u>"
    elseif direction == "down" then
      keymap = "<C-d>"
    else
      vim.api.nvim_err_writeln "Unexpected scroll direction"
      return
    end

    keys.send(keymap, { mode = "n" })
  else
    local lines = 5

    local keymap

    if direction == "up" then
      keymap = "<C-y>"
    elseif direction == "down" then
      keymap = "<C-e>"
    else
      vim.api.nvim_err_writeln "Unexpected scroll direction"
      return
    end

    local floating_windows = windows.get_floating_tab_windows()

    if floating_windows and #floating_windows == 1 and floating_windows[1] ~= current_win then
      local win = floating_windows[1]
      vim.api.nvim_set_current_win(win)
      m.scroll_vertical(direction)
    else
      keys.send(tostring(lines) .. keymap, { mode = "n" })
    end
  end
end

return M
