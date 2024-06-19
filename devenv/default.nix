{
  pkgs,
  ansiEscape,
  ...
}: let
  project-build = pkgs.writeShellApplication {
    name = "project-build";
    runtimeInputs = [pkgs.watchexec];
    text = ''
      watchexec -r -- 'cake lint; cake dead; cake dscheck'
    '';
  };
in {
  name = "cake";

  packages = with pkgs; [
    age-plugin-yubikey
    agenix
    alejandra
    just
    nil
    project-build
    rage
    statix
    cake
    yj
  ];

  enterShell = ansiEscape ''
     echo -e "
      {bold}{106}Cake{reset}
    "
  '';
}
