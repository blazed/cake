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
  { { "FocusGained" }, { pattern = "*", command = "checktime" } },
  { { "Filetype" },    { pattern = "markdown", command = "lua vim.b.minitrailspace_disable = true" } },
  { { "TermOpen" },    { pattern = "*", command = "lua vim.b.minitrailspace_disable = true" } },
  { { "FocusGained" }, { pattern = "*", command = "checktime" } },
  {
    { "FocusLost" },
    {
      pattern = "*",
      callback = function()
        -- for some reason, ++nested doesn't trigger BufWritePre
        -- also, when loosing focus when filetree is active, neovide panics - hence `silent!`
        vim.cmd "silent! doautocmd BufWritePre <afile>"
        vim.cmd "silent! wa"
      end,
    },
  },
  {
    { "BufWritePre" },
    {
      pattern = "*",
      callback = function()
        local filetype = vim.bo.filetype
        local clients = vim.lsp.get_active_clients()

        local client

        for _, c in ipairs(clients) do
          if c.config ~= nil and c.config.filetypes ~= nil then
            for _, ft in ipairs(c.config.filetypes) do
              if ft == filetype and c.server_capabilities.documentFormattingProvider then
                client = c
                break
              end
            end
          end

          if client then
            break
          end
        end

        if client then
          vim.lsp.buf.format { async = false }
        else
          local bufname = vim.fn.expand "<afile>"
          local bufnr = vim.fn.bufnr(bufname)

          if bufnr == -1 then return end

          local modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")

          if modifiable then
            vim.api.nvim_buf_set_lines(0, 0, vim.fn.nextnonblank(1) - 1, true, {})
          end
        end
      end,
    },
  },
  {
    { "Filetype" },
    {
      pattern = "rust",
      callback = function()
        vim.api.nvim_buf_del_keymap(0, "n", "<D-r>")
      end,

    },
  },
  {
    { "User" },
    {
      pattern = "AlphaReady",
      callback = require("plugins.alpha").on_open,
    },
  },
  {
    { "User" },
    {
      pattern = "AlphaClosed",
      callback = require("plugins.alpha").on_close,
    },
  },
}

for _, x in ipairs(autocmds) do
  for _, event in ipairs(x[1]) do
    vim.api.nvim_create_autocmd(event, x[2])
  end
end
