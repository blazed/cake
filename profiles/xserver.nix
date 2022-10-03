{pkgs, ...}: let
  myCustomLayout = pkgs.writeText "xkb-layout" ''
    keycode 9 = dollar asciitilde
  '';
in {
  services.xserver = {
    enable = true;
    videoDrivers = ["nvidia"];
    displayManager = {
      gdm.enable = true;
      gdm.wayland = false;
      defaultSession = "none+i3";
      sessionCommands = ''
        ${pkgs.xorg.xrandr}/bin/xrandr --output DVI-D-4 --off --output HDMI-4 --off --output DP-4 --primary --refresh 144 --mode 2560x1440 --pos 1440x630 --rotate normal --output DP-1 --off --output DP-2 --mode 2560x1440 --pos 4000x630 --rotate normal --output DP-0 --off --output DP-0 --mode 2560x1440 --pos 0x0 --rotate left --output DP-5 --off
        ${pkgs.xorg.xmodmap}/bin/xmodmap ${myCustomLayout}
      '';
    };

    windowManager.i3 = {
      enable = true;
    };

    layout = "us";
    xkbVariant = "dvp";
    xkbOptions = "caps:escape,compose:ralt";
  };
}
