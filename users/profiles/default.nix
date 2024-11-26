{
  config,
  pkgs,
  ...
}: let
  inherit (config.home) username;
in {
  imports = [
    ./alacritty.nix
    ./bat.nix
    ./chromium.nix
    ./dunst.nix
    ./git.nix
    ./neovim/default.nix
    ./nushell/default.nix
    ./rbw.nix
    ./ssh.nix
    ./starship.nix
    ./zellij.nix
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    KUBECONFIG = "/home/${username}/.kube/config";
    COLORTERM = "truecolor";
    USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
  };

  home.packages = with pkgs; [
    carapace
    devenv
    fzf
    go
    google-cloud-sdk
    jwt-cli
    kubectl
    kubectx
    kubelogin-oidc
    kustomize
    lm_sensors
    nix-index
    nodejs
    pueue
    pwgen
    ruby
    scripts
  ];

  xdg.enable = true;

  programs.command-not-found.enable = false;

  programs.lsd = {
    enable = true;
    enableAliases = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.skim.enable = true;

  systemd.user.services.nix-index = {
    Unit.Description = "Nix-index indexes all files in nixpkgs";
    Service.ExecStart = "${pkgs.nix-index}/bin/nix-index";
  };

  systemd.user.timers.nix-index = {
    Unit.Description = "Nix-index indexes all files in nixpkgs";
    Timer = {
      OnCalendar = "*-*-* 4:00:00";
      Unit = "nix-index.service";
    };
    Install.WantedBy = ["timers.target"];
  };

  home.stateVersion = "21.05";
}
