{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (config) gtk;
  swayservice = Description: ExecStart: {
    Unit = {
      inherit Description;
      After = "sway-session.target";
      BindsTo = "sway-session.target";
    };

    Service = {
      Type = "simple";
      Restart = "on-failure";
      inherit ExecStart;
    };

    Install.WantedBy = ["sway-session.target"];
  };

  swaylockTimeout = "300";
  swaylockSleepTimeout = "310";

  swaylockEffects = pkgs.writeShellApplication {
    name = "swaylock-effects";
    runtimeInputs = [pkgs.swaylock-effects];
    text = ''
      exec swaylock \
       --screenshots \
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
    runtimeInputs = [pkgs.sway pkgs.bash swaylockEffects pkgs.swayidle];
    text = ''
      swayidle -d -w timeout ${swaylockTimeout} swaylock-dope \
                     timeout ${swaylockSleepTimeout} 'swaymsg "output * dpms off"' \
                     resume 'sway "output * dpms on"' \
                     before-sleep swaylock-dope
    '';
  };

  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = [pkgs.slurp pkgs.grim];
    text = ''
      mkdir -p ~/Pictures/screenshots
      slurp | grim -g - ~/Pictures/screenshots/"$(date +'%Y-%m-%dT%H%M%S.png')"
    '';
  };

  randomBackground = pkgs.writeShellApplication {
    name = "random-background";
    runtimeInputs = [pkgs.curl];
    text = ''
      curl --silent --fail-with-body -Lo /tmp/background.jpg 'https://source.unsplash.com/featured/2560x1440/?space,nature' 2>/dev/null
      if [ "$(stat -c "%s" "/tmp/background.jpg")" -le 50000 ]; then
        exit 1
      fi
      if [ -e "$HOME"/Pictures/background.jpg ]; then
        mv "$HOME"/Pictures/background.jpg "$HOME"/Pictures/prev-background.jpg
      fi
      mv /tmp/background.jpg "$HOME"/Pictures/background.jpg
      echo "$HOME"/Pictures/background.jpg
    '';
  };

  swayBackground = pkgs.writeShellApplication {
    name = "sway-background";
    runtimeInputs = [randomBackground];
    text = ''
      BG=$(random-background)
      exec swaymsg "output * bg '$BG' fill"
    '';
  };

  rotatingBackground = pkgs.writeShellApplication {
    name = "rotating-background";
    runtimeInputs = [swayBackground pkgs.sway];
    text = ''
      while true; do
      if ! sway-background; then
        if [ -e "$HOME/Pictures/background.jpg" ]; then
            exec swaymsg "output * bg '$HOME/Pictures/background.jpg' fill"
        fi
      fi
      sleep 600
      done
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

  terminal-bin = "${pkgs.alacritty}/bin/alacritty";
  xcursor_theme = gtk.cursorTheme.name;
in {
  home.file.".xkb/symbols/dvp-custom".source = ../files/xkb/dvp-custom;

  home.sessionVariables = {
    GDK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    QT_QPA_PLATFORM = "";
    SDL_VIDEODRIVER = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    XCURSOR_THEME = xcursor_theme;
    XCURSOR_SIZE = "24";
    QT_STYLE_OVERRIDE = lib.mkForce "gtk";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    NIXOS_OZONE_WL = "1";
  };

  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;
    checkConfig = false;
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
        border = 3;
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
        "12815:20541:SONiX_USB_DEVICE_Keyboard" = {
          xkb_layout = "dvp-custom";
        };
        "1739:52710:DLL096D:01_06CB:CDE6_Touchpad" = {
          dwt = "true";
          natural_scroll = "true";
          tap = "true";
        };
      };

      output = {
        "*" = {
          bg = "~/Pictures/background.jpg fill";
        };
        "ASUSTek COMPUTER INC PG279QE #ASMJ3N131Wnd" = {
          mode = "2560x1440@143.998Hz";
          pos = "2560 0";
        };
        "LG Electronics 27GL850 007NTUW8L254" = {
          mode = "2560x1440@144.000Hz";
          pos = "5120 0";
        };
        "LG Electronics 27GL850 007NTWG5A929" = {
          mode = "2560x1440@144.000Hz";
          pos = "0 0";
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

        "${modifier}+Shift+h" = "move left";
        "${modifier}+Shift+j" = "move down";
        "${modifier}+Shift+k" = "move up";
        "${modifier}+Shift+l" = "move right";

        "${modifier}+Control+Tab" = "[con_mark=_swap] unmark _swap; mark --add _swap; [con_mark=_prev] focus; swap container with mark _swap; [con_mark=_swap] unmark _swap";
        "${modifier}+Control+Left" = "[con_mark=_swap] unmark _swap; mark --add _swap; focus left; swap container with mark _swap; [con_mark=_swap] unmark _swap";
        "${modifier}+Control+Right" = "[con_mark=_swap] unmark _swap; mark --add _swap; focus right; swap container with mark _swap; [con_mark=_swap] unmark _swap";
        "${modifier}+Control+Down" = "[con_mark=_swap] unmark _swap; mark --add _swap; focus down; swap container with mark _swap; [con_mark=_swap] unmark _swap";

        "${modifier}+space" = "exec persway stack-swap-main";
        "${modifier}+Control+space" = "exec persway stack-main-rotate-next";
        "${modifier}+Tab" = "exec persway stack-focus-next";
        "${modifier}+Shift+Tab" = "exec persway stack-focus-prev";
        "${modifier}+minus" = "exec persway change-layout spiral";
        "${modifier}+z" = "exec persway change-layout stack-main --size 70";
        "${modifier}+c" = "exec persway change-layout stack-main --size 70 --stack-layout tiled";

        "${modifier}+Shift+s" = ''exec ${screenshot}/bin/screenshot'';

        "${modifier}+Escape" = ''mode "(p)oweroff, (s)uspend, (h)ibernate, (r)eboot, (l)ogout"'';
        "${modifier}+x" = ''mode "disabled keybindings"'';
        "${modifier}+r" = ''mode "resize"'';

        "${modifier}+Shift+x" = ''exec ${swaylockEffects}/bin/swaylock-effects'';

        "${modifier}+i" = ''exec ${pkgs.sway}/bin/swaymsg inhibit_idle open'';
        "${modifier}+Shift+i" = ''exec ${pkgs.sway}/bin/swaymsg inhibit_idle none'';

        "${modifier}+Shift+v" = ''splith'';

        "${modifier}+Shift+a" = ''scratchpad show'';

        "${modifier}+Return" = ''exec ${terminal-bin}'';
        "${modifier}+d" = ''exec ${pkgs.rofi-wayland}/bin/rofi -show drun'';

        "${modifier}+b" = ''exec ${swayBackground}/bin/sway-background'';

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
          command = "${pkgs.polkit_gnome.out}/libexec/polkit-gnome-authentication-agent-1";
        }
        {
          command = "${swayOnReload}/bin/sway-on-reload";
          always = true;
        }
      ];

      bars = [];
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

      seat * xcursor_theme Nordzy-cursors 24
    '';
  };

  systemd.user.services = {
    rotating-background = swayservice "Rotating background service" "${rotatingBackground}/bin/rotating-background";
    persway = swayservice "Small Sway IPC Daemon" "${pkgs.persway}/bin/persway daemon -e '[tiling] opacity 1' -f '[tiling] opacity 0.95; opacity 1' -l 'mark --add _prev' -d stack_main";
    swayidle = swayservice "Sway Idle Service" "${swayidleCommand}/bin/swayidle";
  };
}
