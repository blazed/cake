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

  swayFocusWindow = pkgs.writeStrictShellScriptBin "sway-focus-window" ''
    export SK_OPTS="--no-bold --color=bw  --height=40 --reverse --no-hscroll --no-mouse"
    window="$(${pkgs.sway}/bin/swaymsg -t get_tree | \
              ${pkgs.jq}/bin/jq -r '.nodes | .[] | .nodes | . [] | select(.nodes != null) | .nodes | .[] | select(.name != null) | "\(.id?) \(.name?)"' | \
              ${pkgs.scripts}/bin/sk-sk | \
              awk '{print $1}')"
    ${pkgs.sway}/bin/swaymsg "[con_id=$window] focus"
  '';

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
          border = 3;
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
          border = 3;
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

          "${modifier}+Shift+q" = ''kill'';
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
            colors = {
              background = "#2E3440AA";
              statusline = "#88C0D0";
              separator = "#3B4252";

              focusedWorkspace = {
                border = "#88C0D0";
                background = "#88C0D0";
                text = "#2E3440";
              };

              activeWorkspace = {
                border = "#4C566ADD";
                background = "#4C566ADD";
                text = "#D8DEE9";
              };

              inactiveWorkspace = {
                border = "#3B4252DD";
                background = "#3B4252DD";
                text = "#E5E9F0";
              };

              urgentWorkspace = {
                border = "#B48EAD";
                background = "#B48EAD";
                text = "#ECEFF4";
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
