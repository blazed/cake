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
    telegram-desktop
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
      "application/x-extension-htm" = "firefox.desktop";
      "application/x-extension-html" = "firefox.desktop";
      "application/x-extension-shtml" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "application/x-extension-xhtml" = "firefox.desktop";
      "application/x-extension-xht" = "firefox.desktop";
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
