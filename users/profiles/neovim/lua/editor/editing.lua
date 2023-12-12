local M = {}
local m = {}

function M.keymaps()
  K.map { "y", "Copy selected text", [["+y]], mode = "v" }
  K.map { "<C-S-v>", "Paste text", m.paste, mode = { "i", "c" } }

  K.map {
    "p",
    "Don't replace clipboard content when pasting",
    function() return 'pgv"' .. vim.v.register .. "ygv" end,
    mode = "v",
    expr = true,

  }

  K.map { "d", "Don't replace clipboard content when deleting", [["_d]], mode = { "n", "v" } }
  K.map { "s", "Don't replace clipboard content when inserting", [["xs]], mode = "v" }
  K.map { "c", "Don't replace clipboard content when changing", [["xc]], mode = { "n", "v" } }

  K.map { "<M-d>", "Duplicate line", [["yyy"yp]], mode = "n" }
  K.map { "<M-d>", "Duplicate line", [[<Esc>"yyy"ypgi]], mode = "i" }
  K.map { "<M-d>", "Duplicate selection", [["yy'>"ypgv]], mode = "v" }

  K.map { "<M-Up>", "Move line up", "<Cmd>m .-2<CR>==", mode = "n" }
  K.map { "<M-Down>", "Move line down", "<Cmd>m .+1<CR>==", mode = "n" }
  K.map { "<M-Up>", "Move line up", "<Esc><Cmd>m .-2<CR>==gi", mode = "i" }
  K.map { "<M-Down>", "Move line down", "<Esc><Cmd>m .+1<CR>==gi", mode = "i" }
  K.map { "<M-Up>", "Move selected lines up", ":m '<-2<CR>gv=gv", mode = "v" }
  K.map { "<M-Down>", "Move selected lines down", ":m '>+1<CR>gv=gv", mode = "v" }

  K.map { "<space>", "Drop search highlight", "<Cmd>silent noh<CR>", mode = "n", silent = false }
end

-- Private
--
function m.paste()
  local keys = require "editor.keys"

  local mode = vim.fn.mode()

  if mode == "i" or mode == "c" then
    local paste = vim.o.paste
    local fopts = vim.o.formatoptions

    vim.o.paste = true
    vim.o.formatoptions = fopts:gsub("[crota]", "")

    keys.send("<C-r>+", { mode = "n" })

    vim.defer_fn(
      function()
        vim.o.paste = paste
        vim.o.formatoptions = fopts
      end,
      10
    )
  else
    vim.api.nvim_err_writeln("Unexpected mode")
  end
end

return M
