local M = {}

function M.setup(config)
  config.ts_ls.setup {
    on_attach = function(client)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end,
  }
end

return M
