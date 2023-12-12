{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (config) home;
in {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withRuby = true;
    package = pkgs.neovim-unwrapped;
    extraPackages = with pkgs; [
      docker-compose-language-service
      dockerfile-language-server-nodejs
      gopls
      lua-language-server
      marksman
      nil
      rust-analyzer
      tailwindcss-language-server
      vscode-langservers-extracted
      yaml-language-server
    ];
    extraLuaConfig = ''
      require "neovide"
      require "settings"
      require "globals"
      require "plugins"
      require "keymaps"
      require "commands"
    '';
    plugins = with pkgs.vimPlugins; [
      alpha-nvim
      cmp-buffer
      cmp-cmdline
      cmp-nvim-lsp
      cmp-nvim-lua
      cmp-path
      cmp-vsnip
      codeium-vim
      comment-nvim
      direnv-vim
      lsp_lines-nvim
      lspkind-nvim
      lspsaga-nvim
      lualine-nvim
      luasnip
      neodev-nvim
      noice-nvim
      nui-nvim
      nvim-autopairs
      nvim-cmp
      nvim-lspconfig
      nvim-spectre
      nvim-web-devicons
      onedark-nvim
      rust-tools-nvim
      telescope-file-browser-nvim
      telescope-nvim
      todo-comments-nvim
      toggleterm-nvim
      which-key-nvim
      zen-mode-nvim
      # fzf-vim
      # lsp_signature-nvim
      # neoai
      # neosnippet-snippets
      # neosnippet-vim
      # nord-vim
      # nordic-nvim
      # nvim-dap
      # plenary-nvim
      # rust-vim
      # tabular
      # typescript-tools-nvim
      # vim-fugitive
      # vim-highlightedyank
      # vim-jsonnet
      # vim-markdown
      # vim-matchup
      # vim-nix
      # vim-repeat
      # vim-rooter
      # vim-sneak
      # vim-surround
      # vim-terraform
      # vim-toml
      # vim-vsnip
      # vim-yaml
      # vimagit
      (nvim-treesitter.withPlugins (
        plugins:
          with plugins; [
            tree-sitter-bash
            tree-sitter-comment
            tree-sitter-css
            tree-sitter-dockerfile
            tree-sitter-go
            tree-sitter-graphql
            tree-sitter-hcl
            tree-sitter-html
            tree-sitter-javascript
            tree-sitter-json
            tree-sitter-lua
            tree-sitter-markdown
            tree-sitter-markdown_inline
            tree-sitter-nix
            tree-sitter-nu
            tree-sitter-org-nvim
            tree-sitter-proto
            tree-sitter-regex
            tree-sitter-rego
            tree-sitter-rust
            tree-sitter-sql
            tree-sitter-toml
            tree-sitter-tsx
            tree-sitter-typescript
            tree-sitter-vue
            tree-sitter-yaml
          ]
      ))
    ];
  };
  xdg.configFile."nvim/lua".source = ./lua;
}
