{pkgs, ...}: let
  initConfig = import ../files/nvim/init.nix {inherit pkgs;};

  customPlugins = {
    vim-copilot = pkgs.vimUtils.buildVimPlugin {
      name = "vim-copilot";
      meta.homepage = "https://github.com/github/copilot.vim";
      src = pkgs.fetchFromGitHub {
        owner = "github";
        repo = "copilot.vim";
        rev = "c01314840b94da0b9767b52f8a4bbc579214e509";
        sha256 = "sha256-gnFiuXpKF55cWxCXNXe3zqQaVmGoUV5aRBGIlyUUfIM=";
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
    package = pkgs.neovim-nightly;
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
      vim-surround
      vim-rooter
      fzf-vim
      vim-toml
      vim-yaml
      vim-nix
      rust-vim
      tabular
      vim-markdown
      vim-jsonnet
      vim-terraform
      neosnippet-vim
      neosnippet-snippets
      vim-commentary
      vim-repeat
      editorconfig-vim
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
      customPlugins.vim-copilot
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
        }
      }
    }
  '';
}
