{
  inputs,
  self,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: let
    inherit (lib // builtins) filterAttrs mapAttrs readDir mapAttrs';
    locallyDefinedPackages = mapAttrs (
      name: _: (pkgs.callPackage (../packages + "/${name}") {inherit inputs;})
    ) (filterAttrs (_filename: type: type == "directory") (readDir ../packages));
    old_pkgs =
      import (builtins.fetchGit {
        url = "https://github.com/NixOS/nixpkgs/";
        ref = "refs/heads/nixpkgs-unstable";
        rev = "6f69acaa23bfbcaa5d91723bb49f58a7924077e7";
        shallow = true;
      }) {
        inherit system;
      };
  in {
    packages =
      (
        mapAttrs' (hostname: config: {
          name = "${hostname}-diskformat";
          value = pkgs.callPackage ../utils/diskformat.nix {
            inherit config;
            inherit lib;
          };
        })
        self.nixosConfigurations
      )
      // locallyDefinedPackages
      // {
        cake = pkgs.writeShellApplication {
          name = "cake";
          runtimeInputs = with pkgs; [just nushell statix deadnix];
          text = ''
            just -f ${../Justfile} -d "$(pwd)" "$@"
          '';
        };
        persway = inputs.persway.packages.${system}.default;
        candle = inputs.candle.packages.${system}.default;

        flaresolverr-patched = pkgs.flaresolverr.overrideAttrs (oa: {
          meta = oa.meta // {broken = false;};

          postPatch = ''
            substituteInPlace src/undetected_chromedriver/patcher.py \
              --replace-fail \
                "from distutils.version import LooseVersion" \
                "from looseversion import LooseVersion"

            substituteInPlace src/utils.py \
              --replace-fail \
                'CHROME_EXE_PATH = None' \
                'CHROME_EXE_PATH = "${lib.getExe old_pkgs.chromium}"' \
              --replace-fail \
                'PATCHED_DRIVER_PATH = None' \
                'PATCHED_DRIVER_PATH = "${lib.getExe old_pkgs.undetected-chromedriver}"'
          '';
        });

        inherit
          (inputs.hyprland.packages.${system})
          hyprland
          hyprland-unwrapped
          xdg-desktop-portal-hyprland
          ;
      };
  };
}
