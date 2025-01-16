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
      actionlint
      docker-compose-language-service
      dockerfile-language-server-nodejs
      eslint_d
      gofumpt
      gopls
      gotools
      lsp-ai
      lua-language-server
      marksman
      nil # Nix
      nodePackages.prettier
      nodePackages.typescript-language-server
      rust-analyzer
      shellcheck
      statix
      tailwindcss-language-server
      terraform-ls
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
      CopilotChat-nvim
      alpha-nvim
      cmp-buffer
      cmp-cmdline
      cmp-nvim-lsp
      cmp-nvim-lua
      cmp-path
      cmp-vsnip
      comment-nvim
      copilot-cmp
      copilot-lua
      crates-nvim
      direnv-vim
      gitsigns-nvim
      lsp_lines-nvim
      lspkind-nvim
      lspsaga-nvim
      lualine-nvim
      luasnip
      neodev-nvim
      noice-nvim
      nui-nvim
      null-ls-nvim
      nvim-autopairs
      nvim-cmp
      nvim-lspconfig
      nvim-spectre
      nvim-web-devicons
      onedark-nvim
      onenord-nvim
      plenary-nvim
      rustaceanvim
      telescope-file-browser-nvim
      telescope-nvim
      todo-comments-nvim
      toggleterm-nvim
      vim-highlightedyank
      vim-jjdescription
      which-key-nvim
      zen-mode-nvim
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
