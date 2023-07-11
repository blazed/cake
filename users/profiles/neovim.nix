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
      neoai
      onedark-vim
      lightline-vim
      vim-matchup
      vim-highlightedyank
      vim-sneak
      # coc-nvim
      # coc-go
      # coc-fzf
      # coc-prettier
      # coc-rls
      # coc-json
      # coc-rust-analyzer
      vim-surround
      vim-rooter
      fzf-vim
      vim-toml
      vim-yaml
      vim-nix
      tabular
      vim-markdown
      vim-jsonnet
      vim-terraform
      neosnippet-vim
      neosnippet-snippets
      vim-commentary
      vim-repeat
      copilot-vim
      nui-nvim
      nvim-lspconfig
      rust-vim
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      nvim-cmp
      cmp-vsnip
      vim-vsnip
      lsp_signature-nvim
      # editorconfig-vim
      vim-fugitive
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
      vimagit
    ];
  };

  home.file.".config/nvim/coc-settings.json".text = ''
    {
      "coc.preferences.formatOnSaveFiletypes": [
        "go",
        "json",
        "rust"
      ],
      "languageserver": {
        "golang": {
          "command": "${pkgs.gopls}/bin/gopls",
          "rootPatterns": ["go.mod"],
          "filetypes": ["go"]
        },
        "jsonnet": {
          "command": "${pkgs.jsonnet-language-server}/bin/jsonnet-language-server",
          "args": ["-t"],
          "rootPatterns": [".git/", "jsonnetfile.json"],
          "filetypes": ["jsonnet", "libsonnet"]
        }
      },
      "rust-analyzer.server.path": "${pkgs.rust-analyzer}/bin/rust-analyzer"
    }
  '';
}
