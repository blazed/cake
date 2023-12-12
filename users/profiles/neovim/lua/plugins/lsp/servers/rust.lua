local M = {}

function M.setup(config)
  local rust_tools = require "rust-tools"

  rust_tools.setup {
    server = {
      settings = {
        ["rust-analyzer"] = {
          checkOnSave = {
            command = "clippy",
          },
          inlay_hints = {
            bindingModeHints = {
              enable = true,
            },
            lifetimeElisionHints = {
              enable = "always",
            },
            reborrowHints = {
              enable = "always",
            }
          }
        },
      },
    },
  }
end

return M
