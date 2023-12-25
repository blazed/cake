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
            },
          },
          procMacro = {
            ignored = {
              ["async-trait"] = { "async_trait" },
              ["tracing"] = { "instrument" },
              ["tokio"] = { "main", "test" },
            },
          },
        },
      },
    },
  }
end

return M
