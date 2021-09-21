{ pkgs }:
let
  initConfig = import ../files/nvim/init.nix { inherit pkgs; };
in
{
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
      vim-surround
      vim-rooter
      fzf-vim
      vim-nix
      vim-toml
      vim-yaml
      rust-vim
      vim-go
      tabular
      vim-markdown
      vim-jsonnet
      neosnippet-vim
      neosnippet-snippets
      vim-commentary
      vim-repeat
      editorconfig-vim
      vim-fugitive
      vim-terraform
      nvim-treesitter
      vimagit
    ];
  };
}
