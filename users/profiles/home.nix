{
  pkgs,
  config,
  ...
}: let
  inherit (config) home gtk;
in {
  home.packages = with pkgs; [
    carapace
    codeium
    discord
    firefox-devedition-bin
    fzf
    gnome.nautilus
    go
    google-cloud-sdk
    insomnia
    jwt-cli
    kanshi
    krew
    kubectl
    kubectx
    kubelogin-oidc
    kustomize
    ledger-live-desktop
    lm_sensors
    lutris
    monero-cli
    # monero-gui
    neovide
    netns-dbus-proxy
    nix-index
    nodejs
    persway
    pueue
    pwgen
    ruby
    scripts
    scrot
    signal-desktop
    spotify
    tdesktop ## Telegram
    virt-manager
    vulkan-loader
    wl-clipboard
    wl-clipboard-x11
    xdg-utils
  ];

  home.sessionVariables = rec {
    EDITOR = "nvim";
    VISUAL = EDITOR;
    KUBECONFIG = "/home/${home.username}/.kube/config";
    COLORTERM = "truecolor";
    XCURSOR_THEME = gtk.cursorTheme.name;
    USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
  };

  xdg.enable = true;
  xdg.configFile."mimeapps.list".force = true;
  xdg.mime.enable = true; ## default is true
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "application/x-extension-htm" = "Chromium.desktop";
      "application/x-extension-html" = "Chromium.desktop";
      "application/x-extension-shtml" = "Chromium.desktop";
      "application/x-extension-xhtml" = "Chromium.desktop";
      "application/x-extension-xht" = "Chromium.desktop";
    };

    defaultApplications = {
      "text/html" = "Chromium.desktop";
      "x-scheme-handler/http" = "Chromium.desktop";
      "x-scheme-handler/https" = "Chromium.desktop";
      "x-scheme-handler/about" = "Chromium.desktop";
      "x-scheme-handler/unknown" = "Chromium.desktop";
      "x-scheme-handler/chrome" = "Chromium.desktop";
      "application/x-exension-htm" = "Chromium.desktop";
      "application/x-exension-html" = "Chromium.desktop";
      "application/x-exension-shtml" = "Chromium.desktop";
      "application/xhtml+xml" = "Chromium.desktop";
      "application/x-exension-xhtml" = "Chromium.desktop";
      "application/x-exension-xht" = "Chromium.desktop";
    };
  };

  base16-theme.enable = true;

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
    style.package = pkgs.adwaita-qt;
  };

  gtk = {
    enable = true;
    font = {
      package = pkgs.roboto;
      name = "Roboto Medium 11";
    };
    cursorTheme = {
      package = pkgs.nordzy-cursor-theme;
      name = "Nordzy-cursors";
    };
    iconTheme = {
      package = pkgs.nordzy-icon-theme;
      name = "Nordzy-dark";
    };
    theme = {
      package = pkgs.nordic;
      name = "Nordic-darker";
    };
  };

  programs.command-not-found.enable = false;

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
