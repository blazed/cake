{pkgs, ...}: let
  initConfig = import ../files/nvim/init.nix {inherit pkgs;};

  customPlugins = {
    neoai = pkgs.vimUtils.buildVimPlugin {
      name = "neoai";
      meta.homepage = "https://github.com/Bryley/neoai.nvim";
      src = pkgs.fetchFromGitHub {
        owner = "Bryley";
        repo = "neoai.nvim";
        rev = "b90180e30d143afb71490b92b08c1e9121d4416a";
        sha256 = "sha256-XLQp7i5SOzLkVHCbqUMk+ujcA4Uzpew3VjNAXw6WM8I=";
      };
    };
  };
in {
  programs.neovim = {
    enable = true;
    extraConfig = initConfig.config;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withRuby = true;
    package = pkgs.neovim-unwrapped;
    plugins = with pkgs.vimPlugins // customPlugins; [
      cmp-buffer
      cmp-nvim-lsp
      cmp-path
      cmp-vsnip
      copilot-vim
      fzf-vim
      lightline-vim
      lsp_signature-nvim
      neoai
      neosnippet-snippets
      neosnippet-vim
      nui-nvim
      nvim-cmp
      nvim-lspconfig
      nvim-dap
      onedark-vim
      plenary-nvim
      rust-tools-nvim
      rust-vim
      tabular
      vim-commentary
      vim-fugitive
      vim-highlightedyank
      vim-jsonnet
      vim-markdown
      vim-matchup
      vim-nix
      vim-repeat
      vim-rooter
      vim-sneak
      vim-surround
      vim-terraform
      vim-toml
      vim-vsnip
      vim-yaml
      vimagit
      (nvim-treesitter.withPlugins (
        plugins:
          with plugins; [
            tree-sitter-bash
            tree-sitter-go
            tree-sitter-json
            tree-sitter-nix
            tree-sitter-rust
            tree-sitter-toml
            tree-sitter-yaml
          ]
      ))
    ];
  };
}
