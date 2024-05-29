local autocmds = {
  {
    { "VimEnter" },
    {
      callback = function()
        if vim.v.vim_did_enter then
          vim.cmd "LualineRenameTab editor"
        end
      end,
    },
  },
  {
    { "BufEnter" },
    {
      pattern = "*",
      callback = function()
        if vim.bo.ft == "help" then
          vim.api.nvim_command("wincmd L")
        end
      end,
    },
  },
  { { "BufEnter" },    { pattern = { "*.md", "*.mdx" }, command = "setlocal wrap" } },
  { { "BufEnter" },    { pattern = { "*.tf", "*.tfvars" }, command = "setfiletype hcl" } },
  { { "FocusGained" }, { pattern = "*", command = "checktime" } },
  { { "Filetype" },    { pattern = "markdown", command = "lua vim.b.minitrailspace_disable = true" } },
  { { "TermOpen" },    { pattern = "*", command = "lua vim.b.minitrailspace_disable = true" } },
  { { "FocusGained" }, { pattern = "*", command = "checktime" } },
  {
    { "FocusLost" },
    {
      pattern = "*",
      callback = function()
        vim.cmd "silent! wa"
      end,
    },
  },
  {
    { "User" },
    {
      pattern = "AlphaReady",
      callback = require("plugins.alpha").on_open,
    }
  },
  {
    { "User" },
    {
      pattern = "AlphaClosed",
      callback = require("plugins.alpha").on_close,
    }
  },
  {
    { "BufWritePre" },
    {
      pattern = { "*.tf", "*.tfvars" },
      callback = function()
        vim.lsp.buf.format()
      end,
    },
  },
  {
    { "BufWritePre" },
    {
      pattern = { "*.rs" },
      callback = function()
        vim.lsp.buf.format()
      end,
    },
  },
  -- {
  --   { "Filetype" },
  --   {
  --     pattern = "rust",
  --     callback = function()
  --       vim.api.nvim_buf_del_keymap(0, "n", "<D-r>")
  --     end,
  --   },
  -- },
}

for _, x in ipairs(autocmds) do
  for _, event in ipairs(x[1]) do
    vim.api.nvim_create_autocmd(event, x[2])
  end
end
