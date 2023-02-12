{
  pkgs,
  config,
  lib,
  ...
}: let
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

    Install.WantedBy = ["sway-session.target"];
  };

  swaylockTimeout = "300";
  swaylockSleepTimeout = "310";

  swayidleCommand = pkgs.writeShellApplication {
    name = "swayidle";
    runtimeInputs = [pkgs.sway pkgs.bash pkgs.swaylock-dope pkgs.swayidle];
    text = ''
      swayidle -d -w timeout ${swaylockTimeout} swaylock-dope \
                     timeout ${swaylockSleepTimeout} 'swaymsg "output * dpms off"' \
                     resume 'sway "output * dpms on"' \
                     before-sleep swaylock-dope
    '';
  };

  swayOnReload = pkgs.writeShellApplication {
    name = "sway-on-reload";
    runtimeInputs = [pkgs.sway];
    text = ''
      LID=/proc/acpi/button/lid/LID
      if [ ! -e "$LID" ]; then
        LID=/proc/acpi/button/lid/LID0
      fi
      if [ -e "$LID" ]; then
        if grep -q open "$LID"/state; then
            swaymsg output eDP-1 enable
        else
            swaymsg output eDP-1 disable
        fi
      fi

      ${
        lib.optionalString config.services.kanshi.enable
        ''
          systemctl restart --user kanshi.service
        ''
      }
    '';
  };

  fonts = {
    names = ["Roboto" "Font Awesome 5 Free" "Font Awesome 5 Brands" "Arial" "sans-serif"];
    style = "Bold";
    size = 10.0;
  };

  modifier = "Mod4";

  xcursor_theme = "default";
in {
  home.file.".xkb/symbols/dvp-custom".source = ../files/xkb/dvp-custom;

  home.sessionVariables = {
    GDK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland-egl";
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    XCURSOR_THEME = xcursor_theme;
    QT_STYLE_OVERRIDE = lib.mkForce "gtk";
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

      window = let
        command = "floating enable, resize set width 100ppt height 120ppt";
        floatCommand = "floating enable";
      in {
        titlebar = false;
        border = 1;
        hideEdgeBorders = "smart";
        commands = [
          {
            inherit command;
            criteria.class = "scripts";
          }
          {
            inherit command;
            criteria.title = "scripts";
          }
          {
            inherit command;
            criteria.app_id = "scripts";
          }
          {
            command = floatCommand;
            criteria.class = "input-window";
          }
          {
            command = floatCommand;
            criteria.class = "gcr-prompter";
          }
          {
            command = "inhibit_idle fullscreen";
            criteria.shell = ".*";
          }
          {
            command = "kill";
            criteria.title = "Firefox - Sharing Indicator";
          }
        ];
      };

      floating = {
        titlebar = false;
        border = 1;
      };

      input = {
        "*" = {
          xkb_layout = "us,us";
          xkb_options = "compose:ralt,caps:escape";
          xkb_variant = "dvp,";
        };
        "3897:1558:Heng_Yu_Technology_POKER_3C" = {
          xkb_layout = "dvp-custom";
        };
        "1739:52710:DLL096D:01_06CB:CDE6_Touchpad" = {
          dwt = "true";
          natural_scroll = "true";
          tap = "true";
        };
      };

      output = {
        "ASUSTek COMPUTER INC PG279QE #ASMJ3N131Wnd" = {
          mode = "2560x1440@143.998Hz";
          pos = "1440 680";
        };
        "LG Electronics 27GL850 007NTUW8L254" = {
          mode = "2560x1440@144.000Hz";
          pos = "4000 680";
        };
        "LG Electronics 27GL850 007NTWG5A929" = {
          mode = "2560x1440@144.000Hz";
          pos = "0 0";
          transform = "270";
        };
      };

      gaps = {
        inner = 4;
        top = -5;
        bottom = -5;
        left = -5;
        right = -5;
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
        "2" = [{app_id = "firefox";}];
        "4" = [
          {app_id = "telegramdesktop";}
          {class = "Signal";}
        ];
        "6" = [{class = "^discord$";}];
        "7" = [{class = "^Spotify$";}];
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

        "${modifier}+space" = "exec echo sway_visible > $XDG_RUNTIME_DIR/persway";
        "${modifier}+Control+space" = "exec echo master_cycle_next > $XDG_RUNTIME_DIR/persway";
        "${modifier}+Tab" = "exec echo stack_focus_next > $XDG_RUNTIME_DIR/persway";
        "${modifier}+Shift+Tab" = "exec echo stack_focus_prev > $XDG_RUNTIME_DIR/persway";

        "${modifier}+Escape" = ''mode "(p)oweroff, (s)uspend, (h)ibernate, (r)eboot, (l)ogout"'';
        "${modifier}+x" = ''mode "disabled keybindings"'';
        "${modifier}+r" = ''mode "resize"'';

        "${modifier}+Shift+x" = ''exec ${pkgs.swaylock-dope}/bin/swaylock-dope'';

        "${modifier}+Return" = ''exec ${pkgs.alacritty}/bin/alacritty'';
        "${modifier}+d" = ''exec ${pkgs.rofi-wayland}/bin/rofi -show drun'';

        XF86AudioRaiseVolume = ''exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%'';
        XF86AudioLowerVolume = "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
        XF86AudioMute = "exec ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
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
          command = "${pkgs.gnome.gnome-settings-daemon}/libexec/gsd-xsettings";
        }
        {
          command = "${pkgs.dbus.out}/bin/dbus-update-activation-environment 2>/dev/null && ${pkgs.dbus.out}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK";
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
      workspace 1 output DP-1
      workspace 3 output DP-1
      workspace 5 output DP-1

      workspace 2 output DP-2
      workspace 4 output DP-2
      workspace 6 output DP-2

      workspace 7 output DP-3

      no_focus [window_role="browser"]
      popup_during_fullscreen smart
      bindswitch --reload --locked lid:on output eDP-1 disable
      bindswitch --reload --locked lid:off output eDP-1 enable
      titlebar_border_thickness 0
    '';
  };

  systemd.user.services = {
    persway = swayservice "Small Sway IPC Daemon" "${pkgs.persway}/bin/persway -w -e '[tiling] opacity 1' -f '[tiling] opacity 0.95; opacity 1' -l 'mark --add _prev' -d master_stack -a spiral -- /run/user/%U/persway";
    swayidle = swayservice "Sway Idle Service" "${swayidleCommand}/bin/swayidle";
  };
}
