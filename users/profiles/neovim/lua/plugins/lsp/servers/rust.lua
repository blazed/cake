local M = {}

function M.setup()
  vim.g.rustaceanvim = {
    tools = {},
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
    dap = {},
  }
end

return M
