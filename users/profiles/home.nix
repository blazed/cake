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
    go_1_20
    google-cloud-sdk
    insomnia
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
    monero-gui
    neovide
    netns-dbus-proxy
    nix-index
    nodejs
    persway
    pueue
    pwgen
    rnix-lsp
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
  };

  xdg.enable = true;
  xdg.configFile."mimeapps.list".force = true;
  xdg.mime.enable = true; ## default is true
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "application/x-extension-htm" = "firefox.desktop";
      "application/x-extension-html" = "firefox.desktop";
      "application/x-extension-shtml" = "firefox.desktop";
      "application/x-extension-xhtml" = "firefox.desktop";
      "application/x-extension-xht" = "firefox.desktop";
    };

    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
      "x-scheme-handler/chrome" = "firefox.desktop";
      "application/x-exension-htm" = "firefox.desktop";
      "application/x-exension-html" = "firefox.desktop";
      "application/x-exension-shtml" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "application/x-exension-xhtml" = "firefox.desktop";
      "application/x-exension-xht" = "firefox.desktop";
    };
  };

  base16-theme.enable = true;

  qt = {
    enable = true;
    platformTheme = "gnome";
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

  # programs.eza = {
  #   enable = true;
  #   enableAliases = true;
  # };

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
