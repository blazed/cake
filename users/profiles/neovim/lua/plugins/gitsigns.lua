local M = {}

function M.setup()
  local plugin = require "gitsigns"

  plugin.setup {
    signcolumn = true,
    numhl = false,
    linehl = false,
    word_diff = false,
    watch_gitdir = {
      interval = 1000,
      follow_files = true,
    },
    attach_to_untracked = true,
    current_line_blame = false,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol",
      delay = 1000,
      ignore_whitespace = false,
    },
    sign_priority = 6,
    update_debounce = 100,
    status_formatter = nil,
    max_file_length = 40000,
    preview_config = {
      border = "rounded",
      style = "minimal",
      relative = "cursor",
      row = 0,
      col = 1,
    },
  }
end

function M.keymaps()
  K.map { "<M-j>", "Git: Jump to next hunk", "<Cmd>Gitsigns next_hunk<CR>", mode = "n" }
  K.map { "<M-k>", "Git: Jump to previous hunk", "<Cmd>Gitsigns prev_hunk<CR>", mode = "n" }
  K.map { "<C-space>", "Git: Stage hunk", "<Cmd>Gitsigns stage_hunk<CR>", mode = { "n", "v" } }
  K.map { "<C-M-space>", "Git: Unstage hunk", "<Cmd>Gitsigns undo_stage_hunk<CR>", mode = { "n", "v" } }
end

return M
