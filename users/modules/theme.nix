{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    mkMerge
    mkIf
    mkEnableOption
    types
    ;
  cfg = config.base16-theme;
  cnotation = builtins.replaceStrings [ "#" ] [ "0x" ];
  color =
    default:
    mkOption {
      inherit default;
      type = types.str;
    };
  alpha = clr: a: "${clr}${a}";
in
{
  options.base16-theme = {
    enable = mkEnableOption "Enable base16 theme systemwide";
    base00 = color "#1d2021";
    base01 = color "#3c3836";
    base02 = color "#504945";
    base03 = color "#665c54";
    base04 = color "#bdae93";
    base05 = color "#d5c4a1";
    base06 = color "#ebdbb2";
    base07 = color "#fbf1c7";
    base08 = color "#fb4934";
    base09 = color "#fe8019";
    base0A = color "#fabd2f";
    base0B = color "#b8bb26";
    base0C = color "#8ec07c";
    base0D = color "#83a598";
    base0E = color "#d3869b";
    base0F = color "#d65d0e";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      wayland.windowManager.sway.config.colors = rec {
        focused = {
          border = cfg.base0A;
          background = cfg.base0A;
          text = cfg.base06;
          indicator = cfg.base0A;
          childBorder = cfg.base0A;
        };

        focusedInactive = {
          border = cfg.base00;
          background = cfg.base00;
          text = cfg.base07;
          indicator = cfg.base00;
          childBorder = cfg.base00;
        };

        unfocused = focusedInactive;

        urgent = {
          border = cfg.base0B;
          background = cfg.base0B;
          text = cfg.base05;
          indicator = cfg.base0B;
          childBorder = cfg.base0B;
        };
      };

      programs.alacritty.settings.colors = {
        primary.background = "0x1d2021";
        primary.foreground = "0xd5c4a1";

        cursor.text = cnotation cfg.base00;
        cursor.cursor = cnotation cfg.base05;

        normal.black = cnotation cfg.base01;
        normal.red = cnotation cfg.base08;
        normal.green = cnotation cfg.base0B;
        normal.yellow = cnotation cfg.base0A;
        normal.blue = cnotation cfg.base0D;
        normal.magenta = cnotation cfg.base0E;
        normal.cyan = cnotation cfg.base0C;
        normal.white = cnotation cfg.base05;

        bright.black = cnotation cfg.base03;
        bright.red = cnotation cfg.base08;
        bright.green = cnotation cfg.base0B;
        bright.yellow = cnotation cfg.base0A;
        bright.blue = cnotation cfg.base0D;
        bright.magenta = cnotation cfg.base0E;
        bright.cyan = cnotation cfg.base0C;
        bright.white = cnotation cfg.base07;
      };
    }
  ]);
}
