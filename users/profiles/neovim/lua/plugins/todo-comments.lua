local M = {}

function M.setup()
  local plugin = require "todo-comments"

  plugin.setup {
    signs = false,
    colors = {
      todo = { "DiagnosticHint" },
      hack = { "DiagnosticWarn" },
      fixme = { "DiagnosticHint" },
      priority = { "Number" },
    },
    keywords = {
      NB = { icon = "", color = "hint", alt = { "NB!" } },
      HACK = { icon = "", color = "hack" },
      TODO = { icon = "", color = "todo" },
      FIXME = { icon = "", color = "fixme" },
      TODOP = { icon = "", color = "priority", alt = { "TODO!" } },
      FIXMEP = { icon = "", color = "priority", alt = { "FIXME!" } },
    },
    search = {
      pattern = [[\<\(KEYWORDS\)\(([[:alnum:]-]\+)\)\?:]],
      command = "rg",
      args = {
        "--color=never",
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--column",
        "--hidden",
      },
    },
  }
end

return M
