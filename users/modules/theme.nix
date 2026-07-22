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
  color =
    default:
    mkOption {
      inherit default;
      type = types.str;
    };
in
{
  options.base16-theme = {
    enable = mkEnableOption "base16 theme systemwide";
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

    }
  ]);
}
