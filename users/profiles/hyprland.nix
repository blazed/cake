{
  inputs,
  config,
  lib,
  pkgs,
  specialArgs,
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

  swaylockTimeout = "300";
  swaylockSleepTimeout = "310";

  swaylockEffects = pkgs.writeShellApplication {
    name = "swaylock-effects";
    runtimeInputs = [pkgs.swaylock-effects];
    text = ''
      exec swaylock \
       --screenshots \
       --clock \
       --indicator \
       --indicator-radius 100 \
       --indicator-thickness 7 \
       --effect-blur 15x3 \
       --effect-greyscale \
       --ring-color ffffff \
       --ring-clear-color baffba \
       --ring-ver-color bababa \
       --ring-wrong-color ffbaba \
       --key-hl-color bababa \
       --line-color ffffffaa \
       --inside-color ffffffaa \
       --inside-ver-color bababaaa \
       --line-ver-color bababaaa \
       --inside-clear-color baffbaaa \
       --line-clear-color baffbaaa \
       --inside-wrong-color ffbabaaa \
       --line-wrong-color ffbabaaa \
       --separator-color 00000000 \
       --grace 2 \
       --fade-in 0.2
    '';
  };

  swayidleCommand = pkgs.writeShellApplication {
    name = "swayidle";
    runtimeInputs = [pkgs.bash swaylockEffects pkgs.swayidle];
    text = ''
      exec swayidle -d -w timeout ${swaylockTimeout} swaylock-effects \
                     timeout ${swaylockSleepTimeout} 'hyprctl dispatch dpms off' \
                     resume 'hyprctl dispatch dpms on' \
                     before-sleep swaylock-effects
    '';
  };

  dev-env = name: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [wezterm];
    text = ''
      exec wezterm connect --class=${name} ${name}
    '';
  };

  local-dev = dev-env "local-dev";
  remote-dev = dev-env "remote-dev";

  xcursor_theme = config.gtk.cursorTheme.name;
  terminal-bin = "${pkgs.wezterm}/bin/wezterm start --always-new-process";

  inherit (specialArgs) hostName;
in {
  xdg.configFile."wpaperd/wallpaper.toml".source = pkgs.writeText "wallpaper.toml" ''
    [default]
    path = "~/Pictures/wallpapers"
    duration = "30m"
    sorting = "random"
    apply-shadow = false
  '';
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

    bind=,escape,submap,reset
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
        "$mod SHIFT, e, exec, ${local-dev}/bin/local-dev"
        "$mod SHIFT, r, exec, ${remote-dev}/bin/remote-dev"
        "$mod SHIFT, s, exec, ${screenshot}/bin/screenshot"
        "$mod SHIFT, x, exec, ${swaylockEffects}/bin/swaylock-effects"
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, code:14, workspace, 1"
        "$mod, code:17, workspace, 2"
        "$mod, code:13, workspace, 3"
        "$mod, code:18, workspace, 4"
        "$mod, code:12, workspace, 5"
        "$mod, code:19, workspace, 6"
        "$mod, code:11, workspace, 7"
        "$mod, code:20, workspace, 8"
        "$mod, code:15, workspace, 9"
        "$mod SHIFT, code:14, movetoworkspace, 1"
        "$mod SHIFT, code:17, movetoworkspace, 2"
        "$mod SHIFT, code:13, movetoworkspace, 3"
        "$mod SHIFT, code:18, movetoworkspace, 4"
        "$mod SHIFT, code:12, movetoworkspace, 5"
        "$mod SHIFT, code:19, movetoworkspace, 6"
        "$mod SHIFT, code:11, movetoworkspace, 7"
        "$mod SHIFT, code:20, movetoworkspace, 8"
        "$mod SHIFT, code:15, movetoworkspace, 9"
        "$mod, 0, workspace, 10"
        "$mod SHIFT, 0, movetoworkspace, 10"
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        "$mod, f, fullscreen"
        "$mod, g, togglegroup"
        "$mod, Tab, changegroupactive"
        "$mod, space, layoutmsg, swapwithmaster"
        "$mod, m, movecurrentworkspacetomonitor, +1"
        "$mod SHIFT, space, togglefloating"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      misc.disable_hyprland_logo = true;
      misc.disable_splash_rendering = true;

      binds = {
        workspace_back_and_forth = true;
        allow_workspace_cycles = true;
      };

      animations = {
        enabled = true;
        animation = [
          "workspaces,1,0.6,default"
          "windows,1,0.8,default"
          "fade,1,0.8,default"
          "border,1,0.6,default"
          "borderangle,1,0.6,default"
        ];
      };

      decoration = {
        rounding = 4;
        blur = {
          enabled = true;
          size = 7;
          passes = 2;
          xray = true;
          ignore_opacity = true;
          new_optimizations = true;
          noise = 0.12;
          contrast = 1.05;
          brightness = 0.8;
        };
        drop_shadow = false;
        shadow_range = 20;
        shadow_render_power = 2;
        shadow_offset = "3 3";
        "col.shadow" = "0x99000000";
        "col.shadow_inactive" = "0x55000000";
        active_opacity = 0.95;
        inactive_opacity = 0.85;
        fullscreen_opacity = 1.0;
      };

      general = {
        layout = "master";
        border_size = 4;
        gaps_in = 2;
        gaps_out = 0;
        "col.active_border" = "0x36393Eaa";
      };

      master = {
        new_is_master = true;
        orientation = "right";
        mfact = 0.7;
      };

      layerrule = "blur,waybar";

      input = {
        kb_layout = "us";
        kb_variant = "dvp";
        kb_options = "compose:ralt,caps:escape";

        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
        };
      };

      "device:heng-yu-technology-poker-3c" = {
        kb_layout = "dvp-custom";
        kb_variant = "";
        kb_options = "compose:ralt,caps:escape";
      };

      exec = [
        "${pkgs.kanshi}/bin/kanshi"
      ];

      exec-once = [
        "${pkgs.wpaperd}/bin/wpaperd"
        "${pkgs.swayidle}/bin/swayidle"
      ];
  };
}