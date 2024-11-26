local M = {}

M.signs = {
  Error = "ﮊ",
  Warn  = "󱅧",
  Hint  = "﮸",
  Info  = "",
}

function M.setup()
  local lsp = vim.lsp

  local config = require "lspconfig"

  -- local ai = require "plugins.lsp.servers.ai"
  local lua = require "plugins.lsp.servers.lua"
  local rust = require "plugins.lsp.servers.rust"
  local go = require "plugins.lsp.servers.go"
  local typescript = require "plugins.lsp.servers.typescript"
  local yaml = require "plugins.lsp.servers.yaml"

  vim.diagnostic.config {
    signs = true,
    severity_sort = true,
  }

  for type, icon in pairs(M.signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end

  lsp.handlers["textDocument/hover"] = lsp.with(lsp.handlers.hover, { border = "rounded" })

  -- ai.setup()
  lua.setup(config)
  rust.setup()
  go.setup(config)
  typescript.setup(config)
  yaml.setup(config)

  config.cssls.setup {}
  config.dockerls.setup {}
  config.docker_compose_language_service.setup {}
  config.html.setup {}
  config.jsonls.setup {}
  config.marksman.setup {}
  config.nil_ls.setup {}
  config.tailwindcss.setup {}
  config.terraformls.setup {
    filetypes = { "terraform", "tf", "hcl" },
  }
end

return M
