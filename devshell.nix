{ mkDevShell, agenix, age-plugin-yubikey, rage, yj, cakeUtils, lib }:

let
  cakeUtilsList = lib.mapAttrsToList (_: util: util) cakeUtils;
in

mkDevShell {
  name = "cake";
  packages = [ yj rage agenix age-plugin-yubikey ] ++ cakeUtilsList;
  intro = ''

    Write something smart?

  '';
}
