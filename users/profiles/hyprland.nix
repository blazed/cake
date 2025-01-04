{
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
      exec swayidle -d -w timeout ${swaylockTimeout} swaylock-dope \
                     timeout ${swaylockSleepTimeout} 'hyprctl dispatch dpms off' \
                     resume 'hyprctl dispatch dpms on' \
                     before-sleep swaylock-dope
    '';
  };

  xcursor_theme = config.gtk.cursorTheme.name;
  terminal-bin = "${pkgs.alacritty}/bin/alacritty";
in {
  home.file.".xkb/symbols/dvp-custom".source = ../files/xkb/dvp-custom;

  home.sessionVariables = {
    GDK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    QT_QPA_PLATFORM = "";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_WAYLAND_FORCE_DPI = "physical";
    SDL_VIDEODRIVER = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    XCURSOR_THEME = xcursor_theme;
    XCURSOR_SIZE = "24";
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

    workspace=1,monitor:DP-1,default:true
    workspace=3,monitor:DP-1
    workspace=5,monitor:DP-1

    workspace=2,monitor:DP-2,default:true
    workspace=4,monitor:DP-2
    workspace=6,monitor:DP-2

    workspace=7,monitor:DP-3,default:true

    windowrule=workspace 2,class:(chromium-browser)

    windowrulev2=workspace 4,class:(org.telegram.desktop)
    windowrulev2=workspace 4,class:(Signal)

    windowrulev2=workspace 6,class:(discord)

    windowrulev2=workspace 7,class:(Spotify)
  '';

  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind = [
      "$mod, Return, exec, ${terminal-bin}"
      "$mod SHIFT, q, killactive"
      "$mod, d, exec, ${pkgs.rofi-wayland}/bin/rofi -show drun"
      "$mod SHIFT, s, exec, ${screenshot}/bin/screenshot"
      "$mod SHIFT, x, exec, ${swaylockEffects}/bin/swaylock-effects"
      "$mod SHIFT, e, exec, ${pkgs.neovide}/bin/neovide"
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
      "$mod SHIFT, left, movewindoworgroup, l"
      "$mod SHIFT, right, movewindoworgroup, r"
      "$mod SHIFT, up, movewindoworgroup, u"
      "$mod SHIFT, down, movewindoworgroup, d"
      "$mod, f, fullscreen"
      "$mod, g, togglegroup"
      "$mod SHIFT, g, lockactivegroup, toggle"
      "$mod, Tab, changegroupactive, f"
      "$mod SHIFT, Tab, changegroupactive, b"
      "$mod, space, layoutmsg, swapwithmaster"
      "$mod, m, movecurrentworkspacetomonitor, +1"
      "$mod SHIFT, space, togglefloating"
    ];

    binde = [
      ", XF86AudioRaiseVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%"
      ", XF86AudioLowerVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%"
      ", XF86AudioMute, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle"
      ", XF86MonBrightnessUp, exec, light -A 5"
      ", XF86MonBrightnessDown, exec, light -U 5"
    ];

    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];

    misc.disable_hyprland_logo = true;
    misc.disable_splash_rendering = true;

    group = {
      groupbar = {
        font_size = 12;
        gradients = false;
        "col.inactive" = "0x2E344000";
        "col.active" = "0x5E81AC00";
      };
    };

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
      # drop_shadow = false;
      # shadow_range = 20;
      # shadow_render_power = 2;
      # shadow_offset = "3 3";
      # "col.shadow" = "0x99000000";
      # "col.shadow_inactive" = "0x55000000";
      active_opacity = 0.95;
      inactive_opacity = 0.85;
      fullscreen_opacity = 1.0;
    };

    general = {
      layout = "master";
      border_size = 0;
      gaps_in = 2;
      gaps_out = 0;
      "col.active_border" = "0x36393Eaa";
    };

    master = {
      new_status = "master";
      orientation = "right";
      mfact = 0.7;
    };

    input = {
      kb_layout = "us";
      kb_variant = "dvp";
      kb_options = "compose:ralt,caps:escape";

      follow_mouse = 1;

      touchpad = {
        natural_scroll = true;
        disable_while_typing = true;
        tap-to-click = true;
      };
    };

    device = {
      name = "heng-yu-technology-poker-3c";
      kb_layout = "dvp-custom";
      kb_variant = "";
      kb_options = "compose:ralt,caps:escape";
    };

    windowrulev2 = [
      "dimaround,class:gitui"
      "float,class:gitui"
      "size 60% 60%,class:gitui"
      "center,class:gitui"
      "dimaround,class:chrome-nngceckbapebfimnlniiiahkandclblb-Default"
      "float,class:chrome-nngceckbapebfimnlniiiahkandclblb-Default"
      "size 60% 60%,class:chrome-nngceckbapebfimnlniiiahkandclblb-Default"
      "center,class:chrome-nngceckbapebfimnlniiiahkandclblb-Default"
      "dimaround,title:Open File"
      "float,title:Open File"
      "center,title:Open File"
    ];

    exec = [
      "${pkgs.kanshi}/bin/kanshi"
    ];

    exec-once = [
      "${pkgs.wpaperd}/bin/wpaperd"
      "${swayidleCommand}/bin/swayidle"
      "${pkgs.hyprland}/bin/hyprctl setcursor ${xcursor_theme} 24"
      "${pkgs.polkit_gnome.out}/libexec/polkit-gnome-authentication-agent-1"
    ];
  };
}
