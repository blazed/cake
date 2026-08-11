{
  config,
  pkgs,
  ...
}:
let
  inherit (config.home) username;
in
{
  imports = [
    # keep-sorted start
    ./backlog-md.nix
    ./bat.nix
    ./chromium.nix
    ./claude.nix
    ./codex.nix
    ./firefox.nix
    ./git.nix
    ./gitui.nix
    ./jailed-agents.nix
    ./jujutsu.nix
    ./mergiraf.nix
    ./neovim.nix
    ./nh.nix
    ./nushell/default.nix
    ./pi/default.nix
    ./protonpass.nix
    ./protonvpn.nix
    ./ssh.nix
    ./starship.nix
    ./wezterm/default.nix
    ./zellij.nix
    # keep-sorted end
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    KUBECONFIG = "/home/${username}/.kube/config";
    COLORTERM = "truecolor";
  };

  home.packages = with pkgs; [
    aws-vault
    awscli2
    carapace
    devenv
    difftastic
    fzf
    go
    google-cloud-sdk
    jwt-cli
    kubectl
    kubectx
    kubelogin-oidc
    kustomize
    libnotify
    lm_sensors
    lmstudio
    nix-index
    nodejs
    pwgen
    ruby
    scripts
  ];

  xdg.enable = true;

  programs.command-not-found.enable = false;

  programs.lsd = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.skim.enable = true;

  home.stateVersion = "25.05";
}
