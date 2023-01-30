{pkgs, ...}: let
  initConfig = import ../files/nvim/init.nix {inherit pkgs;};
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
    plugins = with pkgs.vimPlugins; [
      onedark-vim
      lightline-vim
      vim-matchup
      vim-highlightedyank
      vim-sneak
      coc-nvim
      coc-go
      coc-fzf
      coc-prettier
      coc-rls
      coc-json
      coc-rust-analyzer
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
      }
    }
  '';
}
