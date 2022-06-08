{
  lib,
  pkgs,
  ...
}: let
  mod = "Mod4";
in {
  xsession.windowManager.i3 = {
    enable = true;

    extraConfig = ''
      workspace 1 output DP-0
      workspace 3 output DP-0
      workspace 5 output DP-0

      workspace 2 output DP-2
      workspace 4 output DP-2
      workspace 6 output DP-2

      workspace 7 output DP-4
    '';

    config = {
      modifier = mod;
      menu = "${pkgs.rofi}/bin/rofi -show run -lines 3 -columns 1";
      terminal = "${pkgs.alacritty}/bin/alacritty";
      workspaceAutoBackAndForth = true;
      window = {
        hideEdgeBorders = "none";
        titlebar = false;
      };
      assigns = {
        "2" = [{class = "Firefox Developer Edition";}];
        "3" = [{class = "Lutris";}];
        "4" = [
          {class = "TelegramDesktop";}
          {class = "Signal";}
        ];
        "6" = [{class = "^discord$";}];
        "7" = [{class = "Spotify";}];
      };
      keybindings = lib.mkOptionDefault {
        "${mod}+j" = "focus left";
        "${mod}+k" = "focus down";
        "${mod}+l" = "focus up";
        "${mod}+semicolon" = "focus right";
        "${mod}+Shift+j" = "move left";
        "${mod}+Shift+k" = "move down";
        "${mod}+Shift+l" = "move up";
        "${mod}+Shift+semicolon" = "move right";
        "${mod}+Shift+x" = "exec ${pkgs.i3lock}/bin/i3lock --color '#222222'";
      };
      startup = [
        {
          command = "${pkgs.nitrogen}/bin/nitrogen --restore";
          always = true;
          notification = false;
        }
        {
          command = "${pkgs.unclutter-xfixes}/bin/unclutter";
          always = false;
          notification = true;
        }
        {
          command = "${pkgs.gnupg}/bin/gpg-connect-agent updatestartuptty /bye >/dev/null";
          always = false;
          notification = false;
        }
        {
          command = "i3-msg workspace 1";
          always = false;
          notification = false;
        }
      ];
      bars = [
        {
          statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-default.toml";
          fonts = ["DejaVu Sans Mono" "FontAwesome 12"];
          position = "top";
          colors = {
            background = "#222222";
            separator = "#666666";
            statusline = "#dddddd";
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
              text = "#888888";
            };
            urgentWorkspace = {
              border = "#2f343a";
              background = "#900000";
              text = "#ffffff";
            };
          };
        }
      ];
    };
  };
}
