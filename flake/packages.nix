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
        system = "x86_64-linux";
      };

    python = pkgs.python3.withPackages (
      ps:
        with ps; [
          bottle
          func-timeout
          prometheus-client
          selenium
          waitress
          xvfbwrapper

          # For `undetected_chromedriver`
          looseversion
          requests
          websockets
        ]
    );
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

        flaresolverr-patched = pkgs.flaresolverr.overrideAttrs (oa: {
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

          installPhase = ''
            mkdir -p $out/{bin,share/${oa.pname}-${oa.version}}
            cp -r * $out/share/${oa.pname}-${oa.version}/.

            makeWrapper ${python}/bin/python $out/bin/flaresolverr \
              --add-flags "$out/share/${oa.pname}-${oa.version}/src/flaresolverr.py" \
              --prefix PATH : "${lib.makeBinPath [pkgs.xorg.xvfb]}"
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
