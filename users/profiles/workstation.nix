{
  pkgs,
  config,
  ...
}:
let
  inherit (config) gtk;
in
{
  imports = [
    ./default.nix
  ]
  ++ [
    ./chromium.nix
    # ./easyeffects.nix
    ./hyprland.nix
    # ./kanshi.nix
    ./lutris.nix
    ./obs.nix
    ./pueue.nix
    ./rofi.nix
    ./sway.nix
    ./waybar.nix
  ];

  home.packages = with pkgs; [
    # kanshi
    beekeeper-studio
    bruno
    discord
    nautilus
    neovide
    nordic
    persway
    scrot
    shotcut
    signal-desktop
    slack
    spotify
    tdesktop # # Telegram
    vulkan-loader
    wl-clipboard
    wl-clipboard-x11
    xdg-utils
  ];

  xdg.configFile."wpaperd/wallpaper.toml".source = pkgs.writeText "wallpaper.toml" ''
    [default]
    path = "~/Pictures/wallpapers"
    duration = "30m"
    sorting = "random"
    apply-shadow = false

    [any]
    group = 1
  '';

  xdg.configFile."mimeapps.list".force = true;
  xdg.mime.enable = true;
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

  home.file."Pictures/wallpapers/default-background.jpg".source =
    "${pkgs.adapta-backgrounds}/share/backgrounds/adapta/tri-fadeno.jpg";

  base16-theme.enable = true;

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
    style.package = pkgs.adwaita-qt;
  };

  home.sessionVariables.XCURSOR_THEME = gtk.cursorTheme.name;

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
      package = pkgs.arc-icon-theme;
      name = "Nordzy-dark";
    };
    theme = {
      package = pkgs.nordic;
      name = "Nordic-darker";
    };
  };
}
