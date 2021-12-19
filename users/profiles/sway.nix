{ pkgs, config, lib, ... }:
let
  swayservice = Description: ExecStart: {
    Unit = {
      inherit Description;
      After = "sway-session.target";
      BindsTo = "sway-session.target";
    };

    Service = {
      Type = "simple";
      inherit ExecStart;
    };

    Install.WantedBy = [ "sway-session.target" ];
  };

  swaylockTimeout = "300";
  swaylockSleepTimeout = "310";

  swayidleCommand = lib.concatStringsSep " " [
    "${pkgs.swayidle}/bin/swayidle -w"
    "timeout ${swaylockTimeout}"
    "'${pkgs.swaylock-dope}/bin/swaylock-dope'"
    "timeout ${swaylockSleepTimeout}"
    "'${pkgs.sway}/bin/swaymsg \"output * dpms off\"'"
    "resume '${pkgs.sway}/bin/swaymsg \"output * dpms on\"'"
    "before-sleep '${pkgs.swaylock-dope}/bin/swaylock-dope'"
  ];

  swayOnReload = pkgs.writeStrictShellScriptBin "sway-on-reload" ''
    LID=/proc/acpi/button/lid/LID
    if [ ! -e "$LID" ]; then
      LID=/proc/acpi/button/lid/LID0
    fi
    if [ ! -e "$LID" ]; then
       echo No lid found - skipping sway reload action
       exit
    fi
    if grep -q open "$LID"/state; then
        swaymsg output eDP-1 enable
    else
        swaymsg output eDP-1 disable
    fi
    ${lib.optionalString config.services.kanshi.enable
    ''
    systemctl restart --user kanshi.service
    ''
    }
  '';

  fonts = {
    names = [ "Roboto" "Font Awesome 5 Free" "Font Awesome 5 Brands" "Arial" "sans-serif" ];
    style = "Bold";
    size = 10.0;
  };

  modifier = "Mod4";

in
{
  home.sessionVariables = {
    DK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland-egl";
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    XCURSOR_THEME = "default";
    QT_STYLE_OVERRIDE = "gtk";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  wayland.windowManager.sway = {
    enable = true;
    systemdIntegration = true;
    config = {
      inherit fonts modifier;

      focus = {
        followMouse = true;
        newWindow = "smart";
        mouseWarping = true;
      };

      workspaceAutoBackAndForth = true;

      window = 
        let
          command = "floating enable, resize set width 100ppt height 120ppt";
          floatCommand = "floating enable";
        in
        {
          titlebar = false;
          border = 1;
          hideEdgeBorders = "smart";
          commands = [
            { inherit command; criteria.class = "scripts"; }
            { inherit command; criteria.title = "scripts"; }
            { inherit command; criteria.app_id = "scripts"; }
            { command = floatCommand; criteria.class = "input-window"; }
            { command = floatCommand; criteria.class = "gcr-prompter"; }
            { command = "inhibit_idle fullscreen"; criteria.shell = ".*"; }
            { command = "kill"; criteria.title = "Firefox - Sharing Indicator"; }
          ];
        };

        floating = {
          titlebar = false;
          border = 1;
        };

        input = {
          "*" = {
            xkb_layout = "us";
            xkb_options = "compose:ralt,caps:escape";
            xkb_variant = "dvp";
          };
          "1739:52710:DLL096D:01_06CB:CDE6_Touchpad" = {
            dwt = "true";
            natural_scroll = "true";
            tap = "true";
          };
        };

        modes = {
          resize = {
            Left = "resize shrink width 10 px or 10 ppt";
            Right = "resize grow width 10 px or 10 ppt";
            Up = "resize shrink height 10 px or 10 ppt";
           Down = "resize grow height 10 px or 10 ppt";
            Return = "mode default";
            Escape = "mode default";
          };

          "disabled keybindings" = {
            Escape = "mode default";
          };

          "(p)oweroff, (s)uspend, (h)ibernate, (r)eboot, (l)ogout" = {
            p = "exec swaymsg 'mode default' && systemctl poweroff";
            s = "exec swaymsg 'mode default' && systemctl suspend-then-hibernate";
            h = "exec swaymsg 'mode default' && systemctl hibernate";
            r = "exec swaymsg 'mode default' && systemctl reboot";
            l = "exec swaymsg 'mode default' && swaymsg exit";
            Return = "mode default";
            Escape = "mode default";
          };
        };

        assigns = {
          "2" = [{ app_id = "firefox"; }];
          "4" = [
            { app_id = "telegramdesktop"; }
            { class = "Signal"; }
          ];
          "6" = [{ class = "^discord$"; }];
          "7" = [{ class = "^Spotify$"; }];
        };

        keybindings = lib.mkOptionDefault {
          "${modifier}+j" = "focus left";
          "${modifier}+k" = "focus down";
          "${modifier}+l" = "focus up";
          "${modifier}+semicolon" = "focus right";

          "${modifier}+Shift+j" = "move left";
          "${modifier}+Shift+k" = "move down";
          "${modifier}+Shift+l" = "move up";
          "${modifier}+Shift+semicolon" = "move right";

          "${modifier}+Escape" = ''mode "(p)oweroff, (s)uspend, (h)ibernate, (r)eboot, (l)ogout"'';
          "${modifier}+x" = ''mode "disabled keybindings"'';
          "${modifier}+r" = ''mode "resize"'';

          "${modifier}+Shift+x" = ''exec ${pkgs.swaylock-dope}/bin/swaylock-dope'';

          "${modifier}+Return" = '' exec ${pkgs.alacritty}/bin/alacritty'';
          "${modifier}+d" = ''exec ${pkgs.rofi-wayland}/bin/rofi -show drun'';

          XF86AudioRaiseVolume = ''exec ${pkgs.pulseaudioLight}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%'';
          XF86AudioLowerVolume = "exec ${pkgs.pulseaudioLight}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
          XF86AudioMute = "exec ${pkgs.pulseaudioLight}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
          XF86MonBrightnessUp = "exec light -A 5";
          XF86MonBrightnessDown = "exec light -U 5";

          "${modifier}+Shift+q" = ''kill'';

        };

        keycodebindings = {
          "${modifier}+Shift+14" = "move container to workspace number 1";
          "${modifier}+Shift+17" = "move container to workspace number 2";
          "${modifier}+Shift+13" = "move container to workspace number 3";
          "${modifier}+Shift+18" = "move container to workspace number 4";
          "${modifier}+Shift+12" = "move container to workspace number 5";
          "${modifier}+Shift+19" = "move container to workspace number 6";
          "${modifier}+Shift+11" = "move container to workspace number 7";
          "${modifier}+Shift+20" = "move container to workspace number 8";
          "${modifier}+Shift+15" = "move container to workspace number 9";

          "${modifier}+14" = "workspace number 1";
          "${modifier}+17" = "workspace number 2";
          "${modifier}+13" = "workspace number 3";
          "${modifier}+18" = "workspace number 4";
          "${modifier}+12" = "workspace number 5";
          "${modifier}+19" = "workspace number 6";
          "${modifier}+11" = "workspace number 7";
          "${modifier}+20" = "workspace number 8";
          "${modifier}+15" = "workspace number 9";
        };

        startup = [
          {
            command = "${pkgs.xorg.xrdb}/bin/xrdb -merge ~/.Xresources";
          }
          {
            command = "${pkgs.gnome3.gnome_settings_daemon}/libexec/gsd-xsettings";
          }
          {
            command = "${pkgs.dbus_tools}/bin/dbus-update-activation-environment 2>/dev/null && ${pkgs.dbus_tools}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK";
          }
          {
            command = "${swayOnReload}/bin/sway-on-reload";
            always = true;
          }
        ];

        bars = [
          {
            inherit fonts;
            extraConfig = ''
              height 25
            '';
            statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-default.toml";
            position = "top";
            colors = {
              background = "#222222";
              statusline = "#dddddd";
              separator = "#666666";

              focusedWorkspace = {
                border = "#0088CC";
                background = "#0088CC";
                text = "#ffffff";
              };

              activeWorkspace = {
                border = "#333333";
                background = "#333333";
                text = "#ffffff";
              };

              inactiveWorkspace = {
                border = "#333333";
                background = "#333333";
                text = "#ffffff";
              };

              urgentWorkspace = {
                border = "#2f343a";
                background = "#900000";
                text = "#ffffff";
              };

              bindingMode = {
                border = "#BF616A";
                background = "#BF616A";
                text = "#E5E9F0";
              };
            };
          }
        ];
      };
      extraConfig = ''
        no_focus [window_role="browser"]
        popup_during_fullscreen smart
        bindswitch --reload --locked lid:on output eDP-1 disable
        bindswitch --reload --locked lid:off output eDP-1 enable
        titlebar_border_thickness 0
      '';
    };

    systemd.user.services = {
      swayidle = swayservice "Sway Idle Service" swayidleCommand;
    };
}
