{
  pkgs,
  ansiEscape,
  ...
}:
let
  createInstallerIso = pkgs.writeShellApplication {
    name = "create-installer-iso";
    text = ''
      if ! [ -L cached-iso.iso ]; then
        ISO="$(nix run github:nix-community/nixos-generators -- -f iso -o result --flake .#installer)"
        ln -s "$ISO" cached-iso.iso
      fi
    '';
  };

  project-build = pkgs.writeShellApplication {
    name = "project-build";
    runtimeInputs = [ pkgs.watchexec ];
    text = ''
      watchexec -r -- 'cake lint; cake dead; cake dscheck'
    '';
  };
in
{
  name = "cake";

  packages = with pkgs; [
    age-plugin-yubikey
    agenix
    cake
    createInstallerIso
    just
    nil
    nixfmt
    nixfmt-tree
    project-build
    rage
    statix
    yj
  ];

  enterShell = ansiEscape ''
     echo -e "
      {bold}{106}Cake{reset}
    "
  '';
}
