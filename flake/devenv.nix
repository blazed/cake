{ inputs, ... }:
{
  imports = [
    inputs.devenv.flakeModule
  ];
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (builtins) replaceStrings;
      esc = "\\e";
      ansiEscape =
        replaceStrings
          [ "{reset}" "{bold}" "{106}" ]
          [
            "${esc}[0m"
            "${esc}[1m"
            "${esc}[38;5;106m"
          ];
    in
    {
      devenv.shells = lib.mapAttrs' (file: _: {
        name = builtins.replaceStrings [ ".nix" ] [ "" ] file;
        value = import "${../devenv}/${file}" { inherit pkgs lib ansiEscape; };
      }) (builtins.readDir ../devenv);
    };
}
