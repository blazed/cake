{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let

  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = [pkgs.slurp pkgs.grim];
    text = ''
      mkdir -p ~/Pictures/screenshots
      slurp | grim -g - ~/Pictures/screenshots/"$(date +'%Y-%m-%dT%H%M%S.png')"
    '';
  };

  xcursor_theme = config.gtk.cursorTheme.name;
  terminal = pkgs.kitty;
  terminal-bin = "${pkgs.kitty}/bin/kitty";
in {
  home.file.".xkb/symbols/dvp-custom".source = ../files/xkb/dvp-custom;

  home.sessionVariables = {
    GDK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland-egl";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_WAYLAND_FORCE_DPI = "physical";
    SDL_VIDEODRIVER = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    XCURSOR_THEME = xcursor_theme;
    QT_STYLE_OVERRIDE = lib.mkForce "gtk";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    NIXOS_OZONE_WL = "1";
  };

  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.extraConfig = ''
    bind=$mod,escape,submap,(p)oweroff, (s)uspend, (h)ibernate, (r)eboot, (l)ogout
    submap=(p)oweroff, (s)uspend, (h)ibernate, (r)eboot, (l)ogout

    bind=,p,exec,systemctl poweroff
    bind=,p,submap,reset

    bind=,s,exec,systemctl suspend-then-hibernate
    bind=,s,submap,reset

    bind=,h,exec,systemctl hibernate
    bind=,h,submap,reset

    bind=,r,exec,systemctl reboot
    bind=,r,submap,reset

    bind=,l,exit
    bind=,l,submap,reset

    bind=,p,escape,reset
    bind=,return,submap,reset
    submap=reset
  '';

  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind = 
      [
        "$mod, Return, exec, ${terminal-bin}"
        "$mod SHIFT, q, killactive"
        "$mod, d, exec, ${pkgs.rofi-wayland}/bin/rofi -show drun"
        "$mod SHIFT, s, exec, ${screenshot/bin/screenshot}"
        "$mod CONTROL, l, exec, ${swaylockEffects}/bin/swaylock-effects"
      ];
  };
}
