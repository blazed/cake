{
  pkgs,
  inputs,
  ...
}:
{
  home.packages = [ pkgs.gpu-screen-recorder ];

  programs.noctalia = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
    systemd.enable = true;
    settings = {
      bar.default = {
        background_opacity = 0.65;
        font_weight = 400;
        margin_edge = 0;
        margin_ends = 0;
        radius = 0;
        thickness = 28;
        start = [
          "launcher"
          "workspaces"
          "spacer_2"
          "network_rx"
          "network_tx"
          "spacer_3"
          "sysmon"
        ];
        end = [
          "caffeine"
          "media"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "tray"
          "control-center"
          "session"
        ];
      };
      location.auto_locate = true;
      nightlight.enabled = true;
      shell = {
        niri_overview_type_to_launch_enabled = true;
        setup_wizard_enabled = false;
        panel.transparency_mode = "glass";
        screen_corners = {
          enabled = true;
          size = 16;
        };
        shadow.direction = "down_right";
      };
      notifications = {
        monitors = [
          "DP-1"
          "eDP-1"
        ];

      };
      theme = {
        builtin = "Nord";
        community_palette = "Miasma";
        templates = {
          enable_builtin_templates = false;
          enable_community_templates = false;
        };
      };
      widget = {
        clock = {
          format = "{:%-I:%M %p}";
        };
        spacer_2.type = "spacer";
        spacer_3.type = "spacer";
        volume = {
          scroll_step = 1;
        };
      };
    };
  };
}
